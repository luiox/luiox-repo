-- uikit 包定义（本仓只存定义，源码来自 github.com/luiox/uikit）
--
-- 机制：git 直连包，add_versions 锁 commit，与 libca/duilib 同款。
-- uikit 是三层结构：design 令牌（JSON）→ core 主题引擎（纯 C++17，跨平台，
-- 不含任何 duilib 头）→ duilib 应用层（控件/主题应用器/无边框窗口，windows）。
-- 主题 JSON 编译期内嵌（embedded_themes.h），运行时零文件依赖，包装后即完整。
--
-- core_only config：只装 core 引擎（不拉 duilib，linux/macos 可用）。
-- 默认 false = 整包（绝大多数消费者的真实需求）。
-- 注意极性：core_only 默认 false 时依赖条件为"非 core_only"，xmake configs
-- 显式传 false 不传导，但这里默认侧（整包）恰好是无害侧，无 micon 教训问题。
--
-- 发版/升级：在 uikit 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。

package("uikit")
    set_homepage("https://github.com/luiox/uikit")
    set_description("duilib visual presets: L1 theme tokens (light/dark), L2 theme engine (pure C++17), L3 duilib controls/applier/frameless (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/uikit.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.1.0 = 首版：清壳 + design 深浅令牌 + core 引擎（19 单测）+ duilib
    -- 控件/应用器/无边框窗口 + CI。b43357c 移除了残留 DuiLib_DuiEditor
    -- submodule（duilib 自本仓包供给，submodule 残留会炸 xmake 克隆递归）；
    -- 该条目发布前原地修正，尚无消费方。后续版本自 main 定版。
    add_versions("0.1.0", "b43357c854903748b84e51082915f65f76bbca34")

    add_configs("core_only", {description = "Install core theme engine only (no duilib layer/dependency; usable on linux/macos).", default = false, type = "boolean"})

    on_load(function (package)
        -- 条件依赖：整包才拉 duilib（duilib 包仅 windows，core_only 使
        -- linux 消费方可安装 uikit）。on_load 动态 add deps 是 xmake 官方模式。
        if not package:config("core_only") then
            package:add("deps", "duilib")
            -- 链接顺序 = ld 依赖序：uikit_duilib 依赖 uikit_core，被依赖者在后。
            package:add("links", "uikit_duilib", "uikit_core")
        else
            package:add("links", "uikit_core")
        end
        -- 语言标准传导：uikit 公开头（core/duilib 两层）按 C++17 语义编写；
        -- 中文 UTF-8 注释进公开头，MSVC 侧 /utf-8 必须随包传导，否则消费方
        -- 编译报 C4819/C2001。
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17", "/utf-8")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        local core_only = package:config("core_only")
        if not core_only and not package:is_plat("windows") then
            raise("uikit: duilib layer is windows-only; on %s use core_only=true", package:plat())
        end
        -- 包安装只装库本体：demo/unittest 均为开发态目标，包构建一律关闭。
        local configs = {
            core_only = core_only,
            tests = false,
            demo = false,
        }
        import("package.tools.xmake").install(package, configs)
        -- 公开头随包装，保持 include 根结构：core 以 "uikit/theme/..."、
        -- duilib 层以 "uikit/duilib/..." 引用，compat.h 又相对拉起 theme 头。
        local includedir = package:installdir("include")
        os.cp("core/include/uikit", includedir)
        if not core_only then
            os.cp("duilib/include/uikit/duilib", path.join(includedir, "uikit"))
        end
        -- 静态库随包装（xmake 默认 builddir 结构 build/<plat>/<arch>/release）。
        local libdir = package:installdir("lib")
        local ext = package:is_plat("windows") and ".lib" or ".a"
        local prefix = package:is_plat("windows") and "" or "lib"
        os.cp(path.join("build", package:plat(), package:arch(), "release", prefix .. "uikit_core" .. ext), libdir)
        if not core_only then
            os.cp(path.join("build", package:plat(), package:arch(), "release", prefix .. "uikit_duilib" .. ext), libdir)
        end
    end)

    on_test(function (package)
        -- L2 引擎自检（core_only 与整包都执行）：解析内嵌浅色主题并取派生色。
        assert(package:check_cxxsnippets({test = [[
            #include "uikit/theme/theme.h"
            int main(int argc, char** argv) {
                const uikit::ResolvedTheme& t = uikit::LightTheme();
                return t.name == "light" && t.text_secondary != 0 && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
        -- L3 整包自检（链接级）：控件工厂函数地址，强制符号解析走
        -- uikit_duilib + uikit_core + duilib 闭包。
        if not package:config("core_only") then
            assert(package:check_cxxsnippets({test = [[
                #include "uikit/duilib/controls.h"
                int main(int argc, char** argv) {
                    auto f = &uikit::duilib::MakeTextButton;
                    return f != nullptr && argc >= 0 ? 0 : 1;
                }
            ]]}, {configs = {languages = "cxx17"}}))
        end
    end)
