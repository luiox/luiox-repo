-- libgarena 包定义（本仓只存定义，源码来自 github.com/luiox/libgarena）
--
-- 机制同 libca：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libgarena 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libgarena），无模块拆分。libgarena 工程自身
-- xmake.lua 自声明 libca 依赖（modules=core，随库升级换版），包沙箱内自解析；
-- 下方 add_deps 是给消费方的传递声明（另一回事，不可省）：
--   - libca / zlib：公开头包含 libca/core/*.hpp（ca::usize 等类型别名），实现
--     引用 libca_core 符号。libca modules 取 luiox 家族统一超集
--     core,str,log,crypto,zip（同一消费图内各包配置必须一致，否则报冲突）；
--     zip 模块链接需要 zlib，随包传递声明。

package("libgarena")
    set_homepage("https://github.com/luiox/libgarena")
    set_description("Bump arena + generational handle pool with dangle detection (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libgarena.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（v2 双层架构，MIT）。
    add_versions("0.0.1", "87eb9c73be7aff15d24dc73621371d1ffe0997bd") -- 迁移基线     2026-10-10
    add_versions("0.0.2", "004da98343a6b8bc57662593f5b9c3761265ad61") -- libca 0.0.14 2026-10-11
    -- 0.0.3 = 质量审查修缮：ensureSlots 补槽位 u32 域上限（越过 kInvalidSlot 走
    -- abortSizeOverflow），createArray 值初始化 / owns 口径注释与文档对齐，测试补
    -- 缺与双配置 skip 审计，README 门面重写；libca 锁 0.0.16。无接口变更。
    add_versions("0.0.3", "dcb27ce94cf69dba76cad459fee1eae41065e74f") -- 质量审查修缮 + libca 0.0.16 2026-10-19
    -- 0.0.4 = Layer B 契约修正：构造期槽元数据不再持有跨构造期引用（重入
    -- create/reserve 受支持）、析构借用断言不按 live_count_ 短路、kNoHandle
    -- 先于 owner 检查报告（空句柄 get 统一 abort）。CONTRIBUTING/SECURITY
    -- 对齐仓库实际边界；CI 新增 Linux debug 作业并对库源启用 ASan 插桩。
    -- 无接口签名变更（行为按契约收紧）。
    add_versions("0.0.4", "9df0bfcab9e39b8441594cb49ad695b40b8c09ee") -- 契约修正 + CI/ASan 2026-10-21

    -- 公开头/实现的传递依赖（见头部链接说明）：省略则消费方分别在编译期
    -- （libca 头）或链接期（libca_core 符号）炸 C1083/LNK2019。
    -- libca modules 对齐消费项目（mjbase/mjt）LUIOX_LIBCA_MODULES 家族统一
    -- 超集：包定义 add_deps 不吃消费方 requireconfs（实测），更小模块集会让
    -- 消费图多出一个 libca 实例（链接闭包多条 -libpath）。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})
    add_deps("zlib")

    on_load(function (package)
        package:add("links", "libgarena")
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
        assert(package:has_cxxincludes("garena/arena.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：真分配一轮（alloc + owns），强制解析 libgarena +
        -- libca_core 的符号链（缺任一传递依赖即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "garena/arena.hpp"
            int main(int argc, char** argv) {
                garena::Arena arena;
                void* p = arena.alloc(64, 8);
                return p != nullptr && arena.owns(p) && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
