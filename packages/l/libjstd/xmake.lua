-- libjstd 包定义（本仓只存定义，源码来自 github.com/luiox/libjstd）
--
-- 机制同 libca：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjstd 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明：headeronly（无链接产物）。头依赖 libca/core/datatype.hpp
-- （基础整数类型），下方 add_deps 传导公开头路径，缺依赖在消费方编译期
-- 炸 C1083。libca modules 取 luiox 家族统一超集（同一消费图内各包的
-- libca 配置必须一致，否则 xmake 报 conflict configs dependencies）。

package("libjstd")
    set_homepage("https://github.com/luiox/libjstd")
    set_description("Java-semantics integer arithmetic / LCG random / string hash header library (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjstd.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（命名空间 jstd，MIT，headeronly）。
    add_versions("0.0.1", "ce7cfc15bf297a655a9d4cbf12a130f8f1516aa4") -- 迁移基线 2026-10-12

    add_deps("libca", {configs = {modules = "core,str,log,crypto,zip"}})

    on_load(function (package)
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
        assert(package:has_cxxincludes("jstd/arith.hpp", {configs = {languages = "cxx17"}}))
        -- 头级自检：溢出回绕 + 字符串哈希确定性（缺 libca 传递依赖即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "jstd/arith.hpp"
            #include "jstd/string_hash.hpp"
            int main() {
                if (jstd::arith::add(2147483647, 1) != (-2147483647 - 1)) return 1;
                return jstd::string_hash::java_string_hash("pkgtest") ==
                       jstd::string_hash::java_string_hash("pkgtest") ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
