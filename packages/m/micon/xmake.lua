-- micon 包定义（本仓只存定义，源码来自 github.com/luiox/micon）
--
-- 机制：git 直连包，add_versions 锁 commit，与 libca 同款。
-- 源内两个互斥静态 target：micon_embed（SVG 资源内嵌，MICON_ENABLE_EMBED=1）/
-- micon_dynamic（运行期从磁盘读 SVG，MICON_ENABLE_EMBED=0）。二者均
-- set_default(false)，故 on_install 按 embed config 点名构建其中一个；
-- 公开 define（MICON_ENABLE_EMBED）/includedir（icons.h）随 target 安装
-- 元数据自动传导给消费方，无需手工 add_includedirs/add_links。
--
-- 发版/升级：在 micon 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。

package("micon")
    set_homepage("https://github.com/luiox/micon")
    set_description("Unified-style SVG icon library: generated C++ assets, embed/runtime variants (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/micon.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.2.0 = 首个入包基线（set_version 与仓库 xmake.lua 对齐，2026-08-30 定版）。
    add_versions("0.2.0", "f1a5a9dac8f87555df5e1b125cf3da52de220354")

    -- 注意极性：config 叫 dynamic(默认 false=内嵌)而不是 embed(默认 true)。
    -- xmake configs 显式传 false 不传导(等价未设置→取默认)，传 true 无此问题；
    -- 默认变体是内嵌，故把"需要显式选择"的一侧做成 true 才可靠。
    add_configs("dynamic", {description = "Load SVG assets from disk at runtime (micon_dynamic); default false = embed assets into the binary (micon_embed).", default = false, type = "boolean"})

    on_install("windows", "linux", "macosx", function (package)
        local target = package:config("dynamic") and "micon_dynamic" or "micon_embed"
        import("package.tools.xmake").install(package, {}, {targets = target})
        -- dynamic 变体运行期要从磁盘读 icons/*.svg，资源目录随包安装
        -- （embed 变体用不到，但体积小，统一安装省一个分支）。
        os.cp("icons", package:installdir())
    end)

    on_test(function (package)
        -- 链接级自检：调用 icons.h 导出函数，强制符号解析走安装的静态库。
        assert(package:check_cxxsnippets({test = [[
            #include "icons.h"
            int main(int argc, char** argv) {
                auto f = &icon::GetIconCount;
                return f() > 0 && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
