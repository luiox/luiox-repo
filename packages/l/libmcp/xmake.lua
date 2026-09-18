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
    -- 0.0.1 头文件安装布局有缺陷（include 拍平，缺 mcp/ 层级），勿消费；仅作历史快照保留。
    add_versions("0.0.1", "b6274c719516dd905d86ae2415a163ef97e6b08d")
    -- 0.0.2 = 头文件安装根修复：add_headerfiles 以 (mcp/...) 为安装根，
    -- 包消费方可 #include <mcp/mcp.hpp>；另含 README 免责声明与 CI。
    add_versions("0.0.2", "1fb871e8e9bd8cfd345b4f8482bf04b78b733a44")

    -- 0.1.0 = dual-era 双协议核心（modern 无状态分派 + server/discover +
    -- resultType 信封）+ Streamable HTTP 双模路由；morpher #947 的
    -- "libmcp vendored 同步 v2" 改道独立仓发版（9 文件与 vendored 内容
    -- 逐字节一致，经 diff 核对）。独立仓 unittest 54/54。
    add_versions("0.1.0", "dcc72bdc014536cbc46c5977bdcb15b33eb26929")
    -- libmcp 公开暴露 libca 类型（mcp.hpp 等），public 传导。
    -- 范围约束（>=0.0.7）：libca 0.0.8 为纯新增 API（opt HelpTable，
    -- morpher#890），向后兼容；消费方项目级精确 pin（如 libca 0.0.8）与
    -- 本传导约束按 xmake 规则统一到消费方版本。
    add_deps("libca >=0.0.7", {public = true})

    on_install("windows", "linux", "macosx", function (package)
        local configs = {}
        -- 包安装只装库本体，单测为开发态目标（拉 gtest）。
        configs.with_tests = false
        import("package.tools.xmake").install(package, configs)
    end)

    -- 消费方语言标准传导：本包及 libca 依赖均为 C++17（本 xmake 包解释器
    -- 不支持 set_languages，用 on_load 注入编译标志，向下游 target 传导）。
    on_load(function (package)
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("mcp/mcp.hpp", {configs = {languages = "cxx17"}}))
    end)
