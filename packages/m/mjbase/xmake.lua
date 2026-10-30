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
--   - libca 0.0.16 统一超集 modules；libjstr / libjzip / libgarena + libjclassfile
--   - 版本门控（on_load）：0.0.5 起 libjbc >=0.4.22 裸下界对齐源仓实钉
--     （0.4.23 系上游仓库清理批无功能差异，libjhasm 0.3.3 沙箱内联词条只到
--     0.4.22）+ libjstd/libjhasm；0.0.3–0.0.4 libjbc 0.4.23 + libjstd/libjhasm
--     （libjbytecode 随 mjbase main 旧栈出清剜除）；0.0.2 及以前 libjbc
--     0.4.15 + libjbytecode
--   - libarchive 3.8.8（openssl3=false）仅 0.0.4 及以前：model 资源解包
--     后端，安装期在包沙箱内经源仓 mjbase-repo 本地覆盖仓自足构建；0.0.5
--     起解包面随 PR #112 下沉消费方，包面不再携带。
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
    add_versions("0.0.2", "f87aa3e0bffdd62996a59bc7cdddfeb69a6bd0ae") -- i18n 生成头回源（导出面补齐生成件，on_test 加 mjbase/i18n.hpp 直验）2026-10-19
    add_versions("0.0.3", "b3dc748f0efa6199f409c82018d0e850e758bf9e") -- workspace 退役 + hierarchy/asm_analyzer 帧查询面（FrameQuery）+ spi 重组（common_super_resolver/frame_rewire 归 spi）；依赖变阵：libjbytecode 剜除、libjbc 0.4.15→0.4.23、新增 libjstd/libjhasm 2026-10-29
    add_versions("0.0.4", "4d7dcc6d0d9d8046596e9a9f9f5a1311953517c3") -- jasm 孤立代理反汇编回归 + libjhasm 0.3.3 接线（混淆语料 CESU-8 孤立代理不再一票否决）2026-10-29
    add_versions("0.0.5", "9b34b34cc9cba50b2a9e810d1b1387badc8a9d9b") -- libarchive 死面摘除：resource_io 解包面随需求下沉消费方，包面依赖同步退场 + libjbc 下界对齐实钉 0.4.22（main，PR #112）2026-10-30
    add_versions("0.0.6", "1b80687921c09d7d82121665616832f97cdc959b") -- shadow 表 rename 后 rebind（PR #113）+ libgarena 0.0.3→0.0.5 / libjdk_finder 0.1.0→0.1.1（PR #114；main tip 定版，包源自带 requires，词条面无新增）2026-10-31

    -- libca modules 对齐消费项目（morpher/mjbase）统一超集：包定义 add_deps
    -- 不吃消费方 requireconfs（实测），更小模块集会让消费图多出一个 libca
    -- 实例（链接闭包多条 -libpath）。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})
    add_deps("zlib")
    add_deps("libjstr")
    add_deps("libgarena")
    add_deps("libjzip")
    add_deps("libjclassfile")

    on_load(function (package)
        -- 依赖随版本变阵（0.0.3 起 mjbase main 剜除旧栈 libjbytecode、
        -- libjbc 升 0.4.23、jasm 文本面底座 libjstd/libjhasm 进包级显式依赖，
        -- 与源仓根 require 清单字面对齐消实例分裂）：既有条目只追加不修改，
        -- 旧版本保持原依赖集可继续安装。
        if package:version():ge("0.0.5") then
            package:add("deps", "libjbc >=0.4.22") -- 裸下界对齐源仓实钉 0.4.22（0.4.23 系上游清理批无功能差异，libjhasm 0.3.3 沙箱内联词条只到 0.4.22）
            package:add("deps", "libjstd 0.0.1")
            package:add("deps", "libjhasm >=0.3.3") -- 裸下界：孤立代理转义修复起（0.3.3）
            -- libarchive 随 PR #112 退场：resource_io 解包面下沉消费方，
            -- 0.0.5 起新代码无 archive_* 符号，包面不再携带（0.0.4 分支
            -- 保留旧修复不动，旧版本保持原依赖集可继续安装）。
        elseif package:version():ge("0.0.4") then
            package:add("deps", "libjbc >=0.4.23")
            package:add("deps", "libjstd 0.0.1")
            package:add("deps", "libjhasm >=0.3.3") -- 裸下界：孤立代理转义修复起（0.3.3）
            -- libarchive：model resource_io 的解包后端（源仓 target add_packages
            -- 私有挂载——包面漏声明让导出的 mjbase.lib 带未解析 archive_* 符号，
            -- 首个包消费方 grunt_cli 链接期实证后补）。
            package:add("deps", "libarchive 3.8.8", {configs = {openssl3 = false}})
        elseif package:version():ge("0.0.3") then
            package:add("deps", "libjbc >=0.4.23")  -- 裸下界：家族 libjbc 升版不被 mjbase 0.0.3 钉死（0.4.24 libca 0.0.16 统一实测兼容）
            package:add("deps", "libjstd 0.0.1")
            package:add("deps", "libjhasm 0.3.2")
        else
            package:add("deps", "libjbc 0.4.15")
            package:add("deps", "libjbytecode")
        end
        package:add("links", "mjbase")
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
            -- bcrypt：libca crypto NT 系。
            package:add("syslinks", "bcrypt")
            -- xmllite：包内 libarchive 静态成员的 xar 读符号（0.0.4 及以前的
            -- final link 需要，public 语义同源仓 target）；0.0.5 起源仓随
            -- libarchive 一并摘 xmllite syslinks，包面对齐不再携带。
            if package:version():lt("0.0.5") then
                package:add("syslinks", "xmllite")
            end
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
        -- i18n.hpp 直验仅 <0.0.3（i18n 面随 cli 退役整体剜除，main 已无此头）。
        assert(package:has_cxxincludes("mjbase/keys.hpp", {configs = {languages = "cxx17"}}))
        assert(package:has_cxxincludes("mjbase/hierarchy/class_hierarchy.hpp", {configs = {languages = "cxx17"}}))
        if package:version():lt("0.0.3") then
            assert(package:has_cxxincludes("mjbase/i18n.hpp", {configs = {languages = "cxx17"}}))
        else
            assert(package:has_cxxincludes("mjbase/util.hpp", {configs = {languages = "cxx17"}}))
        end
    end)
