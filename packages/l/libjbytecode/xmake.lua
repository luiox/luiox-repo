-- libjbytecode 包定义（本仓只存定义，源码来自 github.com/luiox/libjbytecode）
--
-- 弃用注记（RFC 0002 迁移线，2026-10）：libjbytecode 已被 libjbc 取代
-- （mjt/mjbase 产品面完成迁移）。存量消费：mjbase relaxed_verifier（B8 8.7
-- 移植 jhasm::analyze 后退役）。新消费方勿再引入；既有条目按可复现纪律
-- 保留不删。

-- 机制同 libca：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjbytecode 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明：包导出六库（聚合 + 五子库）。聚合库含统一入口头 jbytecode.hpp 与
-- 版本查询接口；消费方一般只链聚合库，links 已按 ld 依赖序（消费者在前）给全
-- 闭包，直接链子库的消费方也能解析。demo 用的 libjzip 不在包内（--with_demo
-- 为开发态目标），需要 Jar 读写时消费方自行 add_requires("libjzip")。
--
-- 传递依赖（省略则消费方在编译期/链接期炸 C1083/LNK2019）：
--   - libca / zlib：公开头与实现引用 core/str/log/crypto 模块符号。libca
--     modules 取 luiox 家族统一超集 core,str,log,crypto,zip（同一消费图内
--     各包配置必须一致，否则 xmake 报 conflict configs dependencies）；zip
--     模块链接需要 zlib，随包传递声明。
--   - libjstr：公开头包含 jstr/*.hpp，实现引用 jstr 转换符号（core 子库）
--   - libgarena：公开头包含 garena/*.hpp，树 API 句柄与 arena 底座

package("libjbytecode")
    set_homepage("https://github.com/luiox/libjbytecode")
    set_description("OW2 ASM equivalent JVM bytecode library for C++17: core/tree/commons/analysis/util (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjbytecode.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（五子库 + 聚合库，MIT）。
    add_versions("0.0.1", "06d67cde4b9fa357e06c95b80107259624134f06") -- 迁移基线     2026-10-10
    add_versions("0.0.2", "bcaea4a7245ba657e4f24ce920c29300fa49ecc7") -- libca 0.0.14 + 家族 0.0.2（1141 用例全绿） 2026-10-11
    -- 0.0.3 = 质量审查修缮：Windows 非 ASCII class 路径经 OsString 转 UTF-16 宽构造
    -- 打开（同 libca zip 修法，打不开时消息带 UTF-8 约定提示）、core/demo 孤儿
    -- target 接入构建、测试 skip 深度审计（6 处空跑/弱化改实断言）、README 门面
    -- 重写；libca 锁 0.0.16。全量 7 套件与 demo 链接实测通过。
    add_versions("0.0.3", "288ceee0f66285c92872338087b99bdc6ba2d32e") -- Windows 路径打开 + skip 审计 + libca 0.0.16 2026-10-19

    -- libca modules 对齐消费项目（mjbase/mjt）LUIOX_LIBCA_MODULES 家族统一
    -- 超集：包定义 add_deps 不吃消费方 requireconfs（实测），更小模块集会让
    -- 消费图多出一个 libca 实例（链接闭包多条 -libpath）。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})
    add_deps("zlib")
    add_deps("libjstr")
    -- 裸名嵌套解析默认取最新版：消费方若在顶层钉定 libgarena 版本，必须镜像
    -- add_requireconfs("libjbytecode.libgarena", {version=..., override=true})
    -- 同步翻转，否则包图内双实例 ODR（公开头按值内嵌 Arena）。0.0.5 起
    -- sizeof 80→88 静默 ABI 变更背景见 libgarena 包定义 ABI 注记。
    add_deps("libgarena")

    on_load(function (package)
        -- ld 依赖序：消费者在前、被依赖在后。
        package:add("links", "libjbytecode")
        package:add("links", "libjbytecode_util")
        package:add("links", "libjbytecode_commons")
        package:add("links", "libjbytecode_analysis")
        package:add("links", "libjbytecode_tree")
        package:add("links", "libjbytecode_core")
        -- 语言标准传导：公开头使用 C++17（同 libca 包口径）。
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        -- 包安装只装库本体：unittest/crossval/demo 均为开发态目标。
        import("package.tools.xmake").install(package, {with_tests = false, with_demo = false})
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("jbytecode/jbytecode.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：tree API 生成一个极简类并序列化，强制解析聚合库 + 五子库
        -- + libjstr/libgarena/libca 的符号链（缺任一环即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "jbytecode/jbytecode.hpp"
            int main(int argc, char** argv) {
                jbytecode::tree::ClassNode node;
                node.visit(jbytecode::core::Opcodes::V1_8,
                           jbytecode::core::Opcodes::ACC_PUBLIC,
                           ca::str::ZUtf8StringRef::from_static("PkgTest"),
                           ca::str::ZUtf8StringRef::from_static(""),
                           ca::str::ZUtf8StringRef::from_static("java/lang/Object"),
                           {});
                return jbytecode::get_lib_version() != nullptr && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
