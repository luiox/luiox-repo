-- libca 包定义（本仓只存定义，源码来自 github.com/luiox/libca）
--
-- 机制：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
-- 私有仓认证走系统 git 凭据（SSH agent / Windows 凭据管理器），无额外配置。
--
-- 发版/升级：在 libca 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。

package("libca")
    set_homepage("https://github.com/luiox/libca")
    set_description("C++ foundation library: core/str/fs/io/json/net/http/log/zip (git direct package)")
    set_license("Apache-2.0")

    add_urls("https://github.com/luiox/libca.git")

    -- 语义版本名 + 锁定 commit。
    add_versions("0.0.1", "1ab29dea31c6649fccc8d83ae3312264a88b5f1f")

    add_configs("zip", {description = "Enable libca.zip module (pulls zlib).", default = true, type = "boolean"})
    add_configs("spdlog", {description = "Enable spdlog backend for libca.log.", default = false, type = "boolean"})
    add_configs("openssl", {description = "Enable optional OpenSSL HTTPS client.", default = false, type = "boolean"})

    on_install("windows", "linux", "macosx", function (package)
        local configs = {}
        -- 包安装只装库本体：em/demo/unittest 均为开发态目标，包构建一律关闭。
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
    end)
