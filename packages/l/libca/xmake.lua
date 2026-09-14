-- libca 包定义（本仓只存定义，源码来自 github.com/luiox/libca）
--
-- 机制：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
-- 私有仓认证走系统 git 凭据（SSH agent / Windows 凭据管理器），无额外配置。
--
-- 发版/升级：在 libca 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明：add_links 覆盖全部模块库（高层模块在前、core 兜底，静态库
-- 只拉取被引用目标，多链无害）；libca_test 不入默认链接（测试支撑库）。
-- libca 源内系统库依赖走各模块 target 的 add_syslinks（ws2_32/user32/
-- bcrypt/dbghelp/dl/pthread/rt），不随安装传导，故包定义按平台补齐。

package("libca")
    set_homepage("https://github.com/luiox/libca")
    set_description("C++ foundation library: core/str/fs/io/json/net/http/log/zip (git direct package)")
    set_license("Apache-2.0")

    add_urls("https://github.com/luiox/libca.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = morpher 原 submodule 指针（2026-08-27）。
    add_versions("0.0.1", "1ab29dea31c6649fccc8d83ae3312264a88b5f1f")
    -- 0.0.2~0.0.5 = 其余消费项目原 submodule 指针快照（迁移期零 API 变化对齐用，
    -- 全部项目对齐同一版本后可废弃）。
    -- 注意 0.0.2（ota_demo 原 pin）是嵌入式代 libca（libca.em 形态、交叉编译
    -- 消费），不适用本包的桌面构建路径，仅为版本编号连续性保留，勿消费。
    add_versions("0.0.2", "0c901e411fbcd6acb28bee2aee3634fcb524332c") -- ota_demo            2026-04-02
    add_versions("0.0.3", "e7d25ac654ad7b7c5b7305388483cde7db94a2ba") -- uikit-repo          2026-07-26
    add_versions("0.0.4", "d6676b8da6b7ae723207e9fe2b34837073b0c2f8") -- lab-duilib/mlaunch  2026-08-23
    add_versions("0.0.5", "0a5f1a21d5772614e3cb30c5be3b7c19aa871008") -- sepacker            2026-08-24
    add_versions("0.0.6", "2d005cbbfe2433864177ce29a5e6d5c94b9f61c0") -- can-dbc/can-toolkit 2026-09-03

    add_configs("zip", {description = "Enable libca.zip module (pulls zlib).", default = true, type = "boolean"})
    add_configs("spdlog", {description = "Enable spdlog backend for libca.log.", default = false, type = "boolean"})
    add_configs("openssl", {description = "Enable optional OpenSSL HTTPS client.", default = false, type = "boolean"})

    -- 全模块链接：高层在前、core 兜底（ld 依赖序）；静态库只拉被引用目标，多链无害。
    add_links("libca_http", "libca_net", "libca_ui", "libca_log", "libca_crypto",
              "libca_yaml", "libca_toml", "libca_xml", "libca_csv", "libca_json",
              "libca_ini", "libca_env", "libca_zip", "libca_uuid", "libca_random",
              "libca_process", "libca_thread", "libca_time", "libca_fs", "libca_io",
              "libca_str", "libca_opt", "libca_core")

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
        -- 早期快照版本尚无 zip/spdlog/openssl 开关，传入为惰性配置，无副作用。
        configs.with_em = false
        configs.with_demo = false
        configs.with_tests = false
        configs.with_zip = package:config("zip")
        configs.with_spdlog = package:config("spdlog")
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
