-- libjdk_finder 包定义（本仓只存定义，源码来自 github.com/luiox/libjdk_finder）
--
-- 机制同 libca：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjdk_finder 仓库定版后，于此文件 add_versions 追加新版本
-- 条目（既有条目只追加不修改）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libjdk_finder）。公开头包含
-- libca/core/datatype.hpp（core 模块基础类型），add_deps 传导公开头路径。
-- libca modules 取 luiox 家族统一超集（同一消费图内各包的 libca 配置
-- 必须一致，否则 xmake 报 conflict configs dependencies）。

package("libjdk_finder")
    set_homepage("https://github.com/luiox/libjdk_finder")
    set_description("JDK & native toolchain (MSVC/gcc/clang) discovery library (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjdk_finder.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（命名空间 jdk_finder，MIT）。
    add_versions("0.0.1", "ee1b9c19ef6c146121020e60a0a1554fa46b1536") -- 迁移基线 2026-10-12

    add_deps("libca", {configs = {modules = "core,str,log,crypto,zip"}})

    on_load(function (package)
        package:add("links", "libjdk_finder")
        -- 语言标准传导：公开头使用 C++17（同 libca 包口径）。
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        -- 包安装只装库本体：unittest 为开发态目标。
        import("package.tools.xmake").install(package, {with_tests = false})
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("jdk_finder/jdk_finder.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：调用 findJdk（只验可用性结构，不 Assert 环境真有 JDK），
        -- 强制解析 libjdk_finder 符号链（缺传递依赖即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "jdk_finder/jdk_finder.hpp"
            int main() {
                auto loc = jdk_finder::findJdk();
                return loc.available || !loc.reason.empty() ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
