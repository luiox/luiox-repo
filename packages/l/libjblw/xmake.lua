-- libjblw 包定义（本仓只存定义，源码来自 github.com/luiox/libjblw）
--
-- 机制同 libca：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjblw 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libjblw）。实现引用 libjbytecode 符号，
-- 公开头包含 libca/core/tag_cast.hpp——两条传导都靠下方 add_deps，缺任一
-- 在消费方编译/链接期炸 C1083/LNK2019。libca modules 取 luiox 家族统一
-- 超集（同一消费图内各包的 libca 配置必须一致，否则报 conflict configs）。

package("libjblw")
    set_homepage("https://github.com/luiox/libjblw")
    set_description("JVM classfile runtime face (annotations/types/code/simulation) read-only modeling (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjblw.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（命名空间 jblw，MIT）。
    add_versions("0.0.1", "1b59b9fc24c263d528c0032cc6287d6797563c94") -- 迁移基线 2026-10-12

    add_deps("libjbytecode")
    add_deps("libca", {configs = {modules = "core,str,log,crypto,zip"}})

    on_load(function (package)
        package:add("links", "libjblw")
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
        assert(package:has_cxxincludes("jblw/version/java_version.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：引用 .cpp 侧定义的静态成员，强制解析 libjblw +
        -- libjbytecode 符号链（缺任一传递依赖即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "jblw/version/java_version.hpp"
            int main() {
                const auto& v = jblw::version::JavaVersion::V1;
                return &v == &v ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
