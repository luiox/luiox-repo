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
-- 链接说明：add_links 覆盖全部模块库（含 libca_test——消费方须自行携带
-- gtest 包），libca resources/i18n 为 header-only 模块无库可链。
-- libca 源内系统库依赖走各模块 target 的 add_syslinks（ws2_32/user32/
-- bcrypt/dbghelp/dl/pthread/rt），不随安装传导，故包定义按平台补齐。

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

    -- libca_str 的 format.hpp 在公开头里包含 fmt/core.h，str 以 fmt(header-only)
    -- 为公开接口依赖——包必须传递声明，消费方才能拿到 fmt 的包含路径。
    add_deps("fmt", {configs = {header_only = true}})

    add_configs("zip", {description = "Enable libca.zip module (pulls zlib).", default = true, type = "boolean"})
    add_configs("spdlog", {description = "Enable spdlog backend for libca.log.", default = false, type = "boolean"})
    add_configs("openssl", {description = "Enable optional OpenSSL HTTPS client.", default = false, type = "boolean"})

    -- 全模块链接：libca_test 在前（依赖 gtest+core，消费方须自带 gtest 包）、
    -- 高层在中、core 兜底（ld 依赖序）；静态库只拉被引用目标，多链无害。
    add_links("libca_test", "libca_http", "libca_net", "libca_ui", "libca_log",
              "libca_crypto", "libca_yaml", "libca_toml", "libca_xml", "libca_csv",
              "libca_json", "libca_ini", "libca_env", "libca_zip", "libca_uuid",
              "libca_random", "libca_process", "libca_thread", "libca_time",
              "libca_fs", "libca_io", "libca_str", "libca_opt", "libca_core")

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
        assert(package:check_cxxsnippets({test = [[
            #include "libca/str/charset.hpp"
            int main(int argc, char** argv) {
                auto f = &ca::str::CharsetConverter::utf8_to_wide;
                return f != nullptr && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
