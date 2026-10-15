-- libjbc 包定义（本仓只存定义，源码来自 github.com/luiox/libjbc）
--
-- 机制同 libjclassfile：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内独立构建
-- 安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjbc 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libjbc）。libjbc 工程自身 xmake.lua 已声明
-- libca 依赖（modules = core,str,log,crypto,zip），包沙箱内自解析；下方
-- add_deps 是给消费方的传递声明（另一回事，不可省）。libca modules 取
-- luiox 家族统一超集 core,str,log,crypto,zip（同一消费图内各包的 libca
-- 配置必须一致，否则 xmake 报 conflict configs dependencies）。
--
-- 许可：libjbc 源仓暂未定 LICENSE 文件（README License TBD），故此处不声明
-- license；上游定版后随新版本条目补上。

package("libjbc")
    set_homepage("https://github.com/luiox/libjbc")
    set_description("node-first JVM bytecode library: lazy classfile DOM with fidelity write-back (git direct package)")

    add_urls("https://github.com/luiox/libjbc.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.1.0 = 首个独立仓基线（core/ir/analysis/type 四层，MIT 预期未定版）。
    add_versions("0.1.0", "78e8ad8ffd7e8c610e8af1123371c46ee3988318") -- v0.1.0 基线  2026-10-14

    add_deps("libca", {configs = {modules = "core,str,log,crypto,zip"}})

    on_load(function (package)
        package:add("links", "libjbc")
        -- 语言标准传导：公开头使用 C++17（同 libjstr/libjclassfile 包口径）。
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        -- 包安装只装库本体：unittest/demo 均为开发态目标。
        import("package.tools.xmake").install(package, {with_tests = false})
        -- v0.1.0 布局归位：工程 headerfiles 模式 src/jbc/(**.hpp) 的括号组把
        -- jbc/ 前缀剥掉了，沙箱产物是 include/{jbc.hpp,core/,ir/,...} 平铺
        -- 布局，公开头的 #include "jbc/..." 解不到。这里整体搬回 include/jbc/
        -- 下；include/jbc 已存在（上游未来修正了布局）则跳过。附带摘掉误入
        -- 安装面的 test_helper（开发态测试基建，非交付物）。
        local includedir = path.join(package:installdir(), "include")
        if not os.isdir(path.join(includedir, "jbc")) then
            local staged = path.join(includedir, "jbc")
            os.mkdir(staged)
            for _, entry in ipairs({"jbc.hpp", "analysis", "core", "ir", "type"}) do
                os.mv(path.join(includedir, entry), path.join(staged, entry))
            end
        end
        os.tryrm(path.join(package:installdir(), "lib", "test_helper.lib"))
        os.tryrm(path.join(package:installdir(), "lib", "libtest_helper.a"))
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("jbc/jbc.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：get_lib_version 强制解析 libjbc + libca 的符号链
        -- （缺任一环即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "jbc/jbc.hpp"
            int main(int argc, char** argv) {
                return jbc::get_lib_version() != nullptr && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
package_end()
