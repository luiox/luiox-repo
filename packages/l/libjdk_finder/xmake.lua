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
    add_versions("0.0.2", "cc7712ec396a3334ce7dedfe9b2f7115e58f87b2") -- findVcvarsAll 枚举兜底（VS 2026）2026-10-14
    add_versions("0.1.0", "30c4012890123fb8685c7823b61f4c0a7a3e99bb") -- API snake_case（破坏性）+ 默认安装位置扫描与 java 版本/发行商查询 2026-10-17
    -- 0.1.1 = 默认安装位置扫描修复：一级目录无论自身是否命中都下探二级
    -- （Temurin/Oracle/Zulu 等厂商嵌套布局此前漏扫）；vcvarsall 经
    -- VCToolsInstallDir 定位时按 UTF-8 边界转码（CJK 安装路径不再乱码）；
    -- MSVC 探测收敛 probe_msvc（cl+INCLUDE 就绪判定与 vcvarsall 补足）。
    -- 无接口变更。
    add_versions("0.1.1", "73609bbd4c0c4f08de1d22ffcdcf6351200eebc1") -- 厂商嵌套布局漏扫修复 + vcvarsall UTF-8 转码 2026-10-30

    -- libca modules：对齐消费项目（mjbase/mjt）root xmake.lua 的
    -- LUIOX_LIBCA_MODULES 家族统一超集。包定义 add_deps 不吃消费方的
    -- requireconfs（实测，沙箱嵌套自解析），任何更小的模块集都会让消费图
    -- 多出一个 libca 实例（链接闭包多条 -libpath）。本库 0.1.0 依赖的
    -- fs/env（FileUtil 枚举、ca::fs::Path 编码边界、ca::env 读取）均在
    -- 超集内，超集化无损；版本走裸名，由消费图的 libca 版本决议。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})

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
        -- 链接级自检：调用主入口（只验可用性结构，不 Assert 环境真有 JDK），
        -- 强制解析 libjdk_finder 符号链（缺传递依赖即在此暴露）。
        -- 0.1.0 起 API 改 snake_case（破坏性），旧版本仍是 camelCase——
        -- 探针按版本分支，共用探针会让 0.0.x 在全新环境安装期必挂
        -- （本地包缓存早于探针改动时被掩盖，CI 首装才暴露）。
        if package:version():ge("0.1.0") then
            assert(package:check_cxxsnippets({test = [[
                #include "jdk_finder/jdk_finder.hpp"
                int main() {
                    auto loc = jdk_finder::find_jdk();
                    return loc.available || !loc.reason.empty() ? 0 : 1;
                }
            ]]}, {configs = {languages = "cxx17"}}))
        else
            assert(package:check_cxxsnippets({test = [[
                #include "jdk_finder/jdk_finder.hpp"
                int main() {
                    auto loc = jdk_finder::findJdk();
                    return loc.available || !loc.reason.empty() ? 0 : 1;
                }
            ]]}, {configs = {languages = "cxx17"}}))
        end
    end)
