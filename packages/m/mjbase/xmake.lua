-- mjbase 包定义（本仓只存定义，源码来自 github.com/luiox/mjbase）
--
-- 机制同 libjbytecode：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- 发版/升级：在 mjbase 仓库定版后于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改）；消费项目自行择机升级。
--
-- 链接说明：包导出单库 mjbase。公开头跨模块伞头在 src/mjbase 根
-- （keys.hpp / i18n.hpp / util.hpp），模块目录头（hierarchy/spi/asm/…）随
-- src 一并导出；翻译文案表已内嵌进库本体（cli ArgParser 单源无下游覆盖时兜底）。
--
-- 消费方自备依赖（不在本包 add_deps 面，各自内联/源内目标；须与安装构建
-- 闭包一致避免实例分裂）：
--   - libjstd / libjhasm / libjblw / libjdk_finder：morpher 仓内已有 shim/
--     源目标；mjbase 的 jasm 文本面沿 libjhasm→libjblw→libjbytecode 链解析
--     （jhasm/jblw 为源仓链接层传递边，包面不显式声明）。
--
-- 包级显式依赖（与源仓根 xmake.lua require 清单一字面对齐，消实例分裂）：
--   - libca 0.0.16 统一超集 modules；libjbc 0.4.15（ir/sir 消费面直连 DOM）
--   - libjstr / libjbytecode / libjzip / libgarena 0.0.3 + libjclassfile 0.0.2
--   - libarchive 3.8.8（openssl3=false）：model 的资源解包后端，安装期在包
--     沙箱内经源仓 mjbase-repo 本地覆盖仓自足构建；消费方若自身亦依赖
--     libarchive 需同配置对齐。
--
-- 包级验证以首个消费方（morpher mjt-dump 换轨批次）实际 add_requires 为准。

package("mjbase")
    set_homepage("https://github.com/luiox/mjbase")
    set_description("Cross-class JVM program analysis & transformation base on libjbc (keys/hierarchy/asm/pass pipeline; git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/mjbase.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓发版（268 源文件；morpher 仓内副本的 air/sir deobf IR
    -- 按归属裁决不入 mjbase，随 mjt-deobf 持有）。测试面含救回的 keys/i18n/util
    -- 第 5 批孤儿测试（Windows 本机预存 4 例 storeLock* 红不计入其它平台）。
    add_versions("0.0.1", "31e6e7f304a524e7a2e0e41e0e474833905e96d0") -- 首发基线 + 孤儿测试面救回 + 导出捕获修正 2026-10-19

    -- libca modules 对齐消费项目（morpher/mjbase）统一超集：包定义 add_deps
    -- 不吃消费方 requireconfs（实测），更小模块集会让消费图多出一个 libca
    -- 实例（链接闭包多条 -libpath）。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})
    add_deps("zlib")
    add_deps("libjbc 0.4.15")
    add_deps("libjstr")
    add_deps("libgarena")
    add_deps("libjzip")
    add_deps("libjbytecode")
    add_deps("libjclassfile")

    on_load(function (package)
        package:add("links", "mjbase")
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
            -- bcrypt：libca crypto NT 系；xmllite：包内 libarchive 静态成员的
            -- xar 读符号（final link 需要，public 语义同源仓 target）。
            package:add("syslinks", "bcrypt", "xmllite")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        -- 包安装只装库本体：unittest 均为开发态目标。
        import("package.tools.xmake").install(package, {with_tests = false})
    end)

    on_test(function (package)
        -- 编译面自检：跨模块伞头 + 深目录头沿安装 include 根解析成功。
        assert(package:has_cxxincludes("mjbase/keys.hpp", {configs = {languages = "cxx17"}}))
        assert(package:has_cxxincludes("mjbase/hierarchy/class_hierarchy.hpp", {configs = {languages = "cxx17"}}))
    end)
