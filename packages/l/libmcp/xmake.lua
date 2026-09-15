-- libmcp 包定义（本仓只存定义，源码来自 github.com/luiox/libmcp）
--
-- libmcp 是建立在 libca（JSON/IO/net/http/crypto/str/core）之上的 C++17
-- MCP（Model Context Protocol，JSON-RPC 2.0）基础库，自 morpher 单体仓
-- libs/libmcp 拆分而来。公开依赖 libca：libmcp 公开头暴露 libca 类型，
-- 包依赖以 public 传导给消费方。

package("libmcp")
    set_homepage("https://github.com/luiox/libmcp")
    set_description("C++17 MCP (Model Context Protocol) library: JSON-RPC 2.0, stdio transport, Streamable HTTP server")
    set_license("Apache-2.0")

    add_urls("https://github.com/luiox/libmcp.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 拆分基线（subtree split 保留 morpher 全部历史 + 独立仓库化适配）。
    add_versions("0.0.1", "b6274c719516dd905d86ae2415a163ef97e6b08d")

    -- libmcp 公开暴露 libca 类型（mcp.hpp 等），public 传导。
    add_deps("libca 0.0.7", {public = true})

    on_install("windows", "linux", "macosx", function (package)
        local configs = {}
        -- 包安装只装库本体，单测为开发态目标（拉 gtest）。
        configs.with_tests = false
        import("package.tools.xmake").install(package, configs)
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("mcp/mcp.hpp", {configs = {languages = "cxx17"}}))
    end)
