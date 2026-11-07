-- libjninfra 包定义（本仓只存定义，源码来自 github.com/luiox/libjninfra）
--
-- 机制同 libjstr：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjninfra 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libjninfra）。公开头为 JNI/JVMTI 面——签名里
-- 出现 jint/jvmtiError，jni.h/jvmti.h 由 libjninfra 0.0.2 起按 dev-only 声明
-- （绝对路径 include 经包安装导出会粘进 installdir 形成非法路径），消费方
-- target 须自带 JAVA_HOME include（JNI 库的本分）。libca 依赖按家族统一
-- 超集声明（同一消费图内各包的 libca 配置必须一致，否则报 conflict
-- configs）。

package("libjninfra")
    set_homepage("https://github.com/luiox/libjninfra")
    set_description("JNI/JVMTI boundary & HotSpot VMStruct read-only view library (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjninfra.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（dump/hotspot/jni/jvmti 四组原语）。
    add_versions("0.0.1", "eeb81848d767f6e11eeca762cc5df5fc1afdcf57") -- 0.0.1 基线 2026-11-07
    -- 0.0.2 = JAVA_HOME include 改 dev-only（绝对路径 public include 经包安装
    -- 导出会粘进 installdir 形成非法路径）+ unittest/smoke_agent 显式补
    -- JAVA_HOME include。包消费方自备 JAVA_HOME（消费方 target 加 include）。
    add_versions("0.0.2", "891dcc58e40351894eb256551ff32045cc678579") -- include 导出修复 2026-11-07

    -- 公开头/实现的传递依赖（省略则消费方/本包 on_test 探针编译期炸
    -- C1083）：jninfra/error.hpp 包含 libca/core/datatype.hpp。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})

    on_load(function (package)
        package:add("links", "libjninfra")
        -- 语言标准传导：公开头使用 C++17。
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
            -- 公开头含 UTF-8 中文注释，消费方编译期（含本包 on_test 探针）
            -- 必须按 UTF-8 读源，GBK ACP 下否则注释吞行致语法错。
            package:add("cxxflags", "/utf-8")
        else
            package:add("cxxflags", "-std=c++17")
        end
        -- 刻意不在包元数据里传导 JAVA_HOME include（见文件头链接说明）。
    end)

    on_install("windows", "linux", "macosx", function (package)
        -- 包安装只装库本体：unittest/smoke_agent 为开发态目标。
        -- 沙箱构建需 JAVA_HOME（jni.h/jvmti.h），由消费方环境提供。
        import("package.tools.xmake").install(package, {with_tests = false})
    end)

    on_test(function (package)
        -- jninfra/error.hpp 传递包含 jni.h/jvmti.h（JDK 头不入包），探针在
        -- configs 按消费方环境现取 JAVA_HOME；未设 JAVA_HOME 时跳过头检查。
        local java_home = os.getenv("JAVA_HOME")
        if java_home then
            local inc = java_home:gsub("\\", "/")
            local configs = {languages = "cxx17", includedirs = {inc .. "/include"}}
            if package:is_plat("windows") then
                table.insert(configs.includedirs, inc .. "/include/win32")
            elseif package:is_plat("linux") then
                table.insert(configs.includedirs, inc .. "/include/linux")
            elseif package:is_plat("macosx") then
                table.insert(configs.includedirs, inc .. "/include/darwin")
            end
            assert(package:has_cxxincludes("jninfra/error.hpp", {configs = configs}))
        end
    end)
