-- libca 包定义（本仓只存定义，源码来自 github.com/luiox/libca）
--
-- 机制：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
-- git 认证走系统凭据（SSH agent / Windows 凭据管理器），无额外配置。
--
-- 发版/升级：在 libca 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明（按需子库）：不再整包 add_links。消费方通过 modules config 选择
-- 需要的模块，on_load 按 MODULE_DEPS 闭包展开并按依赖序传导 links：
--   add_requires("libca 0.0.7", {configs = {modules = "core,str,json"}})
--   modules = "all"（默认）= 除 test 外全部模块。
--   test 模块须显式点名（依赖 gtest，消费方须自带 gtest 包）。
-- 未知名直接 raise，防止拼错静默丢链接。
-- 模块间依赖以 libca/<module>/xmake.lua 的 target add_deps 为准，改 libca
-- 模块依赖时须同步本表。
-- libca 源内系统库依赖走各模块 target 的 add_syslinks（ws2_32/user32/
-- bcrypt/dbghelp/dl/pthread/rt），不随安装传导，故包定义按平台补齐
-- （按平台全量声明，未用到的系统库由链接器自行裁剪，无副作用）。

package("libca")
    set_homepage("https://github.com/luiox/libca")
    set_description("C++ foundation library: core/str/fs/io/json/net/http/log/zip (git direct package)")
    set_license("Apache-2.0")

    add_urls("https://github.com/luiox/libca.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个迁移基线（原 submodule 指针，2026-08-27）。
    add_versions("0.0.1", "1ab29dea31c6649fccc8d83ae3312264a88b5f1f")
    -- 0.0.2~0.0.6 = 存量消费方 submodule 指针快照（迁移期零 API 变化对齐用，
    -- 全部消费方对齐同一版本后可废弃）。
    -- 注意 0.0.2 是嵌入式代 libca（libca.em 形态、交叉编译消费），不适用本包
    -- 的桌面构建路径，仅为版本编号连续性保留，勿消费。
    add_versions("0.0.2", "0c901e411fbcd6acb28bee2aee3634fcb524332c") -- 2026-04-02
    add_versions("0.0.3", "e7d25ac654ad7b7c5b7305388483cde7db94a2ba") -- 2026-07-26
    add_versions("0.0.4", "d6676b8da6b7ae723207e9fe2b34837073b0c2f8") -- 2026-08-23
    add_versions("0.0.5", "0a5f1a21d5772614e3cb30c5be3b7c19aa871008") -- 2026-08-24
    add_versions("0.0.6", "2d005cbbfe2433864177ce29a5e6d5c94b9f61c0") -- 2026-09-03
    -- 0.0.7 = em 拆分发版：libca.em 整体迁出至 luiox/libca-em（PR libca#217 squash），
    -- 本包自此不再含 em；with_em 选项已从 libca 删除（on_install 按版本门控）。
    add_versions("0.0.7", "5d7d0b21dbd6c660be0fc798870cb07df86d706d") -- em 拆分           2026-09-15
    -- 0.0.8 = opt 新增 HelpTable 两列 help 行表（morpher#890）：渲染期 UTF-8 码点计宽补齐，
    -- 替代手工空格对齐；纯新增 API，无不兼容变更。
    add_versions("0.0.8", "560d263f36b257699681371a8d6192079d16ff02") -- opt HelpTable     2026-09-17

    -- libca_str 的 format.hpp 在公开头里包含 fmt/core.h，str 以 fmt(header-only)
    -- 为公开接口依赖——包必须传递声明，消费方才能拿到 fmt 的包含路径。
    add_deps("fmt", {configs = {header_only = true}})

    add_configs("zip", {description = "Enable libca.zip module (pulls zlib).", default = true, type = "boolean"})
    add_configs("spdlog", {description = "Enable spdlog backend for libca.log.", default = false, type = "boolean"})
    add_configs("openssl", {description = "Enable optional OpenSSL HTTPS client.", default = false, type = "boolean"})
    add_configs("modules", {description = "Comma-separated modules to link, e.g. \"core,str,json\"; \"all\" (default) = everything except test.", default = "all", type = "string"})

    -- 模块直接依赖表（源头：libca/<module>/xmake.lua target add_deps）。
    -- 展开 modules config 为依赖序 links：闭包补全直接依赖，逆后序输出
    -- （被依赖者在前，ld 依赖序）。未知名 raise，防拼错静默丢链接。
    on_load(function (package)
        local MODULE_DEPS =
        {
            core       = {},
            collection = {"core"},
            config     = {"core", "json", "fs"},
            crypto     = {"core"},
            csv        = {"core", "str"},
            env        = {"core", "str"},
            fs         = {"core", "str"},
            http       = {"net", "thread", "str"},
            i18n       = {"core", "str"},
            ini        = {"core", "str"},
            io         = {"core", "str"},
            json       = {"core", "str", "fs"},
            log        = {"core", "str"},
            net        = {"io", "str"},
            opt        = {"core", "str"},
            process    = {"core", "str"},
            random     = {"core", "crypto"},
            resources  = {"core"},
            str        = {"core"},
            test       = {"core"},
            thread     = {"core", "str"},
            time       = {"core"},
            toml       = {"core", "str"},
            ui         = {"core", "str"},
            uuid       = {"core", "crypto"},
            xml        = {"core", "str"},
            yaml       = {"core", "str"},
            zip        = {"core"}
        }
        local requested = {}
        local value = package:config("modules")
        if value == nil or value == "" or value == "all" then
            for name, _ in pairs(MODULE_DEPS) do
                if name ~= "test" then
                    requested[name] = true
                end
            end
        else
            for name in value:gmatch("[%w_]+") do
                -- 沙盒边界上的字符串可能是包装对象，直接 [] 索引不命中，
                -- 用 pairs 全等匹配解析模块名（27 项线性扫描，配置期一次性成本）。
                local deps
                for k, v in pairs(MODULE_DEPS) do
                    if tostring(k) == tostring(name) then
                        deps = v
                        break
                    end
                end
                if not deps then
                    raise("libca package: unknown module \"%s\" in modules config (known: core, str, json, ...; \"all\" = everything except test)", tostring(name))
                end
                requested[tostring(name)] = deps
            end
        end
        local ordered = {}
        local marks = {}
        local visit
        visit = function (name)
            if marks[name] == 2 then
                return
            end
            assert(marks[name] ~= 1, "libca package: module dependency cycle at " .. name)
            marks[name] = 1
            for _, dep in ipairs(MODULE_DEPS[name]) do
                visit(dep)
            end
            marks[name] = 2
            table.insert(ordered, name)
        end
        for name, _ in pairs(requested) do
            visit(name)
        end
        -- ordered 依赖在前，links 需要 ld 依赖序（依赖者在后），逆序输出。
        for i = #ordered, 1, -1 do
            package:add("links", "libca_" .. ordered[i])
        end
        -- 语言标准传导：libca 公开头部量使用 C++17（本 xmake 包解释器不支持
        -- set_languages，用 on_load 注入编译标志传导给消费方 target）。
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    -- libca 模块 target 的 add_syslinks 不随包安装传导，此处按平台补齐
    -- （macos 的 dl/pthread 在 libSystem 内，无需声明）。
    if is_plat("windows", "mingw") then
        add_syslinks("User32", "Gdi32", "Bcrypt", "DbgHelp", "Ws2_32")
    elseif is_plat("linux") then
        add_syslinks("dl", "pthread", "rt")
    end

    on_install("windows", "linux", "macosx", function (package)
        local configs = {}
        -- 包安装只装库本体：em/demo/unittest 均为开发态目标，包构建一律关闭。
        -- with_em 自 0.0.7 起已随 em 拆分从 libca 删除，仅对旧版本传递。
        if package:version():lt("0.0.7") then
            configs.with_em = false
        end
        configs.with_demo = false
        configs.with_tests = false
        -- 开关按版本门槛传递：xmake 对未定义 option 报 Invalid option 硬错。
        -- with_spdlog 自 0.0.4（2026-08-23）引入；with_zip 自 0.0.6（2026-09-03）引入。
        if package:version():ge("0.0.4") then
            configs.with_spdlog = package:config("spdlog")
        end
        if package:version():ge("0.0.6") then
            configs.with_zip = package:config("zip")
        end
        configs.with_openssl = package:config("openssl")
        import("package.tools.xmake").install(package, configs)
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("libca/core/result.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：取 str 模块非内联函数地址，强制符号解析走 libca_str+libca_core。
        -- 仅当 str 在链接闭包内时执行（modules 可能只点名 core）。
        local modules = package:config("modules")
        if modules == nil or modules == "" or modules == "all" or modules:find("str", 1, true) then
            assert(package:check_cxxsnippets({test = [[
                #include "libca/str/charset.hpp"
                int main(int argc, char** argv) {
                    auto f = &ca::str::CharsetConverter::utf8_to_wide;
                    return f != nullptr && argc >= 0 ? 0 : 1;
                }
            ]]}, {configs = {languages = "cxx17"}}))
        end
    end)
