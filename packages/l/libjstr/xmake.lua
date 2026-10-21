-- libjstr 包定义（本仓只存定义，源码来自 github.com/luiox/libjstr）
--
-- 机制同 libca：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjstr 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libjstr），无模块拆分。libjstr 工程自身
-- xmake.lua 自声明 libca 依赖（modules=core,str，随库升级换版），包沙箱内自解析；
-- 下方 add_deps 是给消费方的传递声明（另一回事，不可省）：
--   - libca / zlib：公开头包含 libca/core/*.hpp，实现引用 ca::str 符号（libca_str）。
--     libca modules 取 luiox 家族统一超集 core,str,log,crypto,zip（同一消费图内
--     各包的 libca 配置必须一致，否则 xmake 报 conflict configs dependencies）；
--     zip 模块链接需要 zlib，随包传递声明。

package("libjstr")
    set_homepage("https://github.com/luiox/libjstr")
    set_description("JVM Modified UTF-8 (MUTF-8) string container & conversion library (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjstr.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（命名空间定为 jstr，MIT）。
    add_versions("0.0.1", "f01d09a7dc740047af9d774868772aed71bdf771") -- 迁移基线     2026-10-10
    add_versions("0.0.2", "feff166688838ef5e8469ca34a5fb5bbd88059fb") -- libca 0.0.14 2026-10-11
    -- 0.0.3 = strict UTF-8 解码边界修复（C0/C1 overlong 与 F5-F7 越界 lead 拒绝、
    -- 截断独立报 kUnexpectedEnd、validate 恒按 strict）+ unittest 16 个边界用例 +
    -- README 门面重写；libca 锁 0.0.16。错误码分类变化见上游 design.md「错误分类」
    -- 节：UTF-8 截断自 kInvalidUtf8Sequence 改报 kUnexpectedEnd。
    add_versions("0.0.3", "d887e154ddb71c2ae9d7b134e04b014185178bd0") -- strict 解码边界 + libca 0.0.16 2026-10-19
    -- 0.0.4 = 审计修正 + JVM String 码元桥：校验错误分类精确化（UTF-8/MUTF-8
    -- 两侧区分 kInvalidUtf8Sequence / kInvalidMutf8Sequence，截断报 kUnexpectedEnd）、
    -- lenient 替换粒度改按 maximal subpart（一个畸形序列只产出一个 U+FFFD）、
    -- 空视图 data()==nullptr 不再越界。[不兼容] 错误码枚举移除 kUnsupportedCodePoint。
    -- 新增 mutf8_to_wtf8 拥有型重载与 mutf8_to_utf16 / utf16_to_mutf8 码元桥
    -- （Mutf8ToUtf16Options 可选容忍混淆器裸 NUL 与标准 UTF-8 四字节，默认拒绝）。
    add_versions("0.0.4", "ed45844467d324045fcbfe8becd32dd7a6ee5228") -- 审计修正 + UTF-16 码元桥 2026-10-21

    -- 公开头/实现的传递依赖（见头部链接说明）：省略则消费方分别在编译期
    -- （libca 头）或链接期（libca_str 符号）炸 C1083/LNK2019。
    -- libca modules 对齐消费项目（mjbase/mjt）LUIOX_LIBCA_MODULES 家族统一
    -- 超集：包定义 add_deps 不吃消费方 requireconfs（实测），更小模块集会让
    -- 消费图多出一个 libca 实例（链接闭包多条 -libpath）。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})
    add_deps("zlib")

    on_load(function (package)
        package:add("links", "libjstr")
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
        assert(package:has_cxxincludes("jstr/conversion.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：UTF-8→MUTF-8→UTF-8 一个往返，强制解析 libjstr +
        -- libca_str + libca_core 的符号链（缺任一传递依赖即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "jstr/conversion.hpp"
            int main(int argc, char** argv) {
                auto m = jstr::utf8_to_mutf8("pkgtest");
                if (!m.is_ok()) return 1;
                auto u = jstr::mutf8_to_utf8(m.unwrap());
                return u.is_ok() && u.unwrap() == "pkgtest" && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
