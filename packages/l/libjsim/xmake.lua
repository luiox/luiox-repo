-- libjsim 包定义（本仓只存定义，源码来自 github.com/luiox/libjsim）
--
-- 机制同 mjbase/libjbc：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- 发版/升级：在 libjsim 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 布局说明：整包 header-only。核心（src/jsim 四头）与扩展包（ext/jsim：
-- str/num/reflect/indy/jbc 五头）公开头统一按 "jsim/..." 解析且文件名零撞名，
-- 安装时合并进单一 include/jsim/ 根（on_load 显式声明 includedirs 用法，
-- 见下）。
--
-- 依赖说明：核心零依赖红线（libjsim 设计 §9，src/jsim 纯 std 头文件），
-- 核心与 str/num/reflect/indy 扩展不进任何包依赖；唯一外部依赖 libjbc 只挂
-- jsim-jbc 桥面（ext/jsim/jbc.hpp，jbc/ir 会话面 + jbc/core Op），包级经
-- jbc config 显式开闸（默认 false）。极性纪律同 micon 词条：xmake configs
-- 显式传 false 不传导（等价未设置→取默认），需要显式选择的一侧必须做成
-- true，故桥面开 = configs {jbc = true}，core-only 零依赖 = 默认不传。
-- 版本取裸下界 >=0.4.24 对齐 libjsim 源仓实钉，家族 libjbc 升版不被钉死。
--
-- 许可：源仓暂无 LICENSE 文件，set_license 暂缺（上游落地后随词条补）。
--
-- 包级验证以首个消费方实际 add_requires 为准；词条当日已做沙箱隔离装包
-- 验证（桥面 toSimMethod→runEntry 端到端 + core-only 双面最小消费程序）。

package("libjsim")
    set_homepage("https://github.com/luiox/libjsim")
    set_description("JVM bytecode single-method simulation framework: header-only core + extension packages built on takeover surfaces (git direct package)")
    -- 整包无库产物，必须显式 headeronly（本代 xmake 语义：kind=library +
    -- headeronly 选项）：缺标记时 xmake 装后做 links 探测，零依赖实例
    -- （jbc=false 无传递 links）直接报 "links not found!" 安装失败。
    set_kind("library", {headeronly = true})

    add_urls("https://github.com/luiox/libjsim.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = jsim-jbc 官方桥扩展包定版基线（核心 4 头 + 扩展 5 头全量进包；
    -- test/demo 四个 binary target 为开发态目标不进包）。
    add_versions("0.0.1", "65ff62f156805b656c184e5312b5cb0230edb7b8") -- jsim-jbc 官方桥扩展包，demo/deobf 消费方桥退役；依赖面：libjbc >=0.4.24 仅挂 jbc 桥面（config 默认关），核心与 str/num/reflect/indy 零包依赖 2026-11-04
    add_versions("0.0.2", "553264c2bfbe34458e1667e7feb664d0c3897ab6") -- 桥搬 indy 调用点与 athrow 异常表 + 引擎区间派发（PR #7），依赖面不变 2026-11-12
    -- 0.0.2 = 桥面 indy/athrow 定版（PR #7）：jbc 桥搬 INVOKEDYNAMIC 调用点
    -- （CallRef：owner 空、NAT name、调用点描述符）与 ATHROW + 异常表折成
    -- Method.handlers（ExRange：pc 边界 + catch 类型，空 = catch-all），引擎
    -- AThrow 区间派发（catch-all 恒派发；具名 catch 堆类名精确相等，无类层次
    -- 面，未知一律 Bail）。依赖面不变：libjbc >=0.4.24 仅挂 jbc 桥面。2026-11-12

    add_configs("jbc", {description = "Declare the jsim-jbc bridge face (ext/jsim/jbc.hpp) with its libjbc dependency; default false = core + str/num/reflect/indy headers only, zero package deps.", default = false, type = "boolean"})

    on_load(function (package)
        -- 用法显式声明：手动 os.cp 布局在零依赖实例（jbc=false，无 lib/ 产物
        -- 与 .pc 用法记录）下不自动传导 installdir/include，消费方解析不到
        -- "jsim/..."；相对路径锚定包安装目录。桥面实例经 libjbc 用法合并
        -- 恰好带上本路径，双实例统一显式声明消差异。
        package:add("includedirs", "include")
        -- 语言标准传导 + 公开头 UTF-8 中文注释的 GBK ACP 防线（同 libjbc
        -- 包口径：on_test 探针只吃 on_load 的 cxxflags，必须显式 /utf-8）。
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
            package:add("cxxflags", "/utf-8")
        else
            package:add("cxxflags", "-std=c++17")
        end
        -- libjbc 只在桥面开闸时进依赖图（核心零依赖红线的包面落实）。
        if package:config("jbc") then
            package:add("deps", "libjbc >=0.4.24")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        -- 包安装只装头文件：核心（src/jsim）+ 扩展（ext/jsim）合并进单一
        -- include/jsim/ 根（文件名零撞名，公开头按 "jsim/..." 解析）。
        local includedir = path.join(package:installdir(), "include", "jsim")
        os.mkdir(includedir)
        os.cp("src/jsim/*.hpp", includedir)
        os.cp("ext/jsim/*.hpp", includedir)
    end)

    on_test(function (package)
        -- 编译面自检：核心伞头 + 扩展代表头沿安装 include 根解析成功。
        assert(package:has_cxxincludes("jsim/engine.hpp", {configs = {languages = "cxx17"}}))
        assert(package:has_cxxincludes("jsim/str.hpp", {configs = {languages = "cxx17"}}))
        -- 桥面仅在开闸时自检（头内 #include "jbc/..." 顺带验证 libjbc 传递）。
        if package:config("jbc") then
            assert(package:has_cxxincludes("jsim/jbc.hpp", {configs = {languages = "cxx17"}}))
        end
    end)
