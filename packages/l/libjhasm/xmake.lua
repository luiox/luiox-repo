-- libjhasm 包定义（本仓只存定义，源码来自 github.com/luiox/libjhasm）
--
-- 机制同 libca：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjhasm 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libjhasm）。后端依赖按版本分支：0.0.x =
-- libjblw → libjbytecode（链接层传递链）；0.3.0 起 = libjbc（后端整体切
-- 换，libjblw/libjbytecode 退役）。公开头另含 libca 头——传导全靠 deps，
-- 缺任一在消费方编译/链接期炸 C1083/LNK2019。libca modules 取 luiox 家族
-- 统一超集（同一消费图内各包的 libca 配置必须一致，否则报 conflict
-- configs）。

package("libjhasm")
    set_homepage("https://github.com/luiox/libjhasm")
    set_description("JAsm JVM assembly text parse/analyze/compile/print library (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjhasm.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（命名空间 jhasm，MIT）。
    add_versions("0.0.1", "f2ed2f0cdc6701526861f7823f100948294287a9") -- 迁移基线 2026-10-12
    -- 0.3.0 = 后端整体切换 libjbc 0.4.18（退役 libjblw/libjbytecode 依赖，
    -- JvmCompilerOptions 改 majorVersion/minorVersion u16 直载，JvmCompileResult
    -- 只带 bytes 不带旧栈模型视图）。
    add_versions("0.3.0", "d1ae5eaab74d0b68a22970562fa21402624d52a0") -- libjbc 后端合入 main 头  2026-10-26
    -- 0.3.1 = strict 复核三面补全（字段操作描述符直读、虚分发接收者/ARETURN
    -- 名字互赋）+ anewarray 落码改组件口径（JVMS 6.5，javac 同形；打印侧
    -- 按 CP 原样，两种既有形态均可往返）。
    add_versions("0.3.1", "2c07b097b1a098d5036961910db199a1c8535b55") -- strict 复核/anewarray 合入 main 头  2026-10-27

    -- 后端依赖按版本分支（uikit 同款 on_load 动态 deps；包定义静态 add_deps
    -- 不吃消费方 requireconfs（实测），故 libca 静态、后端分支动态）。
    -- libca modules 对齐消费项目（mjbase/mjt）LUIOX_LIBCA_MODULES 家族统一
    -- 超集：更小模块集会让消费图多出一个 libca 实例（链接闭包多条
    -- -libpath）。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})

    on_load(function (package)
        if package:version():ge("0.3.0") then
            package:add("deps", "libjbc")
        else
            package:add("deps", "libjblw")
            package:add("deps", "libjbytecode")
        end
        package:add("links", "libjhasm")
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
        assert(package:has_cxxincludes("jhasm/util/range.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：Range::overlap 的 .cpp 侧实现，强制解析 libjhasm 与
        -- 后端传递链符号（缺任一传递依赖即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "jhasm/util/range.hpp"
            int main() {
                return jhasm::util::Range::overlap(0, 2, 1, 3) ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
