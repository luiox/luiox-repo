-- libjzip 包定义（本仓只存定义，源码来自 github.com/luiox/libjzip）
--
-- 机制同 libca：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内
-- 独立构建安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjzip 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libjzip），无模块拆分。libjzip 工程自身
-- xmake.lua 已声明 libca 0.0.13（modules=core,zip,test）与 zlib 依赖，
-- 包沙箱内自解析；下方 add_deps 是给消费方的传递声明（另一回事，不可省）：
--   - libca：公开头包含 libca/core/*.hpp，实现引用 ca::zip::ZipFile/Crc32
--     （libca_zip）。libca modules 取 luiox 家族统一超集 core,str,log,crypto,zip
--     （同一消费图内各包配置必须一致，否则 xmake 报冲突）。
--   - zlib：实现层 8 个文件直接调用 zlib（uncompress/compress 等），静态库
--     留未解析符号，消费方须链 zlib（同 libca 包对 fmt 的传递声明先例）。

package("libjzip")
    set_homepage("https://github.com/luiox/libjzip")
    set_description("JVM-tolerant ZIP/JAR reading & writing library (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjzip.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓基线（自 上游项目 libs/libjzip 快照迁移，MIT）。
    add_versions("0.0.1", "9d7cc2036f274da35f93cd9e9852ea30b7792db4") -- 迁移基线     2026-10-10

    -- 公开头/实现的传递依赖（见头部链接说明）：省略任一条，消费方分别在
    -- 编译期（libca 头）或链接期（libca_zip/zlib 符号）炸 LNK2019/C1083。
    add_deps("libca", {configs = {modules = "core,str,log,crypto,zip"}})
    add_deps("zlib")

    on_load(function (package)
        package:add("links", "libjzip")
        -- 语言标准传导：公开头使用 C++17（同 libca 包口径）。
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        -- 包安装只装库本体：unittest/origintest/crossval 均为开发态目标。
        import("package.tools.xmake").install(package, {with_tests = false})
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("jzip/zip_io.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：真写一个单条目 zip，强制解析 libjzip + libca_zip +
        -- libca_core + zlib 的符号链（缺任一传递依赖即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "jzip/zip_io.hpp"
            #include <memory>
            #include <vector>
            int main(int argc, char** argv) {
                jzip::ZipArchive archive;
                auto part = std::make_unique<jzip::LocalFileHeader>();
                part->setFileName("t");
                part->setFileData(std::vector<ca::u8>{'x'});
                archive.addPart(std::move(part));
                return jzip::ZipIO::writeDirect(archive).size() > 0 && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
