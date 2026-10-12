-- libjclassfile 包定义（本仓只存定义，源码来自 github.com/luiox/libjclassfile）
--
-- 机制同 libjstr：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内独立构建
-- 安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjclassfile 仓库定版后，于此文件 add_versions 追加新版本
-- 条目（既有条目只追加不修改）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libjclassfile）。libjclassfile 工程自身
-- xmake.lua 已声明 libca/libjstr 依赖，包沙箱内自解析；下方 add_deps 是给
-- 消费方的传递声明（另一回事，不可省）。libca modules 取 luiox 家族统一
-- 超集 core,str,log,crypto,zip（同一消费图内各包的 libca 配置必须一致，
-- 否则 xmake 报 conflict configs dependencies）。

package("libjclassfile")
    set_homepage("https://github.com/luiox/libjclassfile")
    set_description("JVM classfile read/write library aligned with CAFED00D core behavior (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjclassfile.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（命名空间未对齐发布版 libjstr，勿消费）。
    -- 0.0.2 = jstr 命名空间对齐发布版 libjstr + 自研测试门面 + 双平台 CI。
    add_versions("0.0.1", "1130c16f35cbcfeef6770ba1f8fb2362e5fc8ff1") -- 基线（勿消费）  2026-10-12
    add_versions("0.0.2", "aabc22e1858279e2d98ef517d7d5160801b85c95") -- 命名空间对齐    2026-10-12

    add_deps("libca", {configs = {modules = "core,str,log,crypto,zip"}})
    add_deps("libjstr")

    on_load(function (package)
        package:add("links", "libjclassfile")
        -- 语言标准传导：公开头使用 C++17（同 libjstr 包口径）。
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
        assert(package:has_cxxincludes("jclassfile/io/class_file_reader.hpp", {configs = {languages = "cxx17"}}))
    end)
package_end()
