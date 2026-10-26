-- libjbc 包定义（本仓只存定义，源码来自 github.com/luiox/libjbc）
--
-- 机制同 libjclassfile：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- xmake 用系统 git 克隆并 checkout 到锁定 commit，随后在本包沙箱内独立构建
-- 安装（不进消费工程的 target 图）。
--
-- 发版/升级：在 libjbc 仓库定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明：整包单库（links = libjbc）。libjbc 工程自身 xmake.lua 已声明
-- libca 依赖（modules = core,str,log,crypto,zip），包沙箱内自解析；下方
-- add_deps 是给消费方的传递声明（另一回事，不可省）。libca modules 取
-- luiox 家族统一超集 core,str,log,crypto,zip（同一消费图内各包的 libca
-- 配置必须一致，否则 xmake 报 conflict configs dependencies）。
--
-- 许可：MIT（源仓 v0.4.12 起 LICENSE 落地）。

package("libjbc")
    set_homepage("https://github.com/luiox/libjbc")
    set_description("node-first JVM bytecode library: lazy classfile DOM with fidelity write-back (git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/libjbc.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.1.0 = 首个独立仓基线（core/ir/analysis/type 四层，MIT 预期未定版）。
    add_versions("0.1.0", "78e8ad8ffd7e8c610e8af1123371c46ee3988318") -- v0.1.0 基线  2026-10-14
    -- 0.4.12 = typed 属性面 13 种 + CP 压缩 + 成员级增删/adopt + 子程序 strict 帧；MIT 定版。
    add_versions("0.4.12", "106cf8302255d18c84b247888724c29bd764a084") -- 重指 GCC 修正版（tag v0.4.12 同 commit；原 a7b12f0 MSVC-only） -- v0.4.12 快照  2026-10-15
    -- 0.4.14 = Nest/Record 属性 typed 建模 + 嵌套属性表 CP 重映射 + nest/record 语料。
    add_versions("0.4.14", "8a00e45613254ba7811b6f196e45afc98c435a9f") -- v0.4.14 快照  2026-10-15
    -- 0.4.15 = Module 族属性 typed 建模 + 压缩封闭集收编；首版测试树完整入库（此前 15+2 文件被忽略规则吞）。
    add_versions("0.4.15", "9f1a13ec3df96f3493703ee3c6fbb7c5186187bf") -- v0.4.15 快照  2026-10-16
    -- 0.4.16 = 里程碑发版：类构建挂载面 + BSM intern 家族 + 消费者协议面（jbc::consumer）+ docs 全量归位 + boar 实语料验证。
    add_versions("0.4.16", "edce61d83be812b933731142b811d82c347b3fc0") -- v0.4.16 发版 main 头  2026-10-17
    -- 0.4.17 = consumer 模块移除（协议面归上层仓单份持有）。
    add_versions("0.4.17", "2a44a3749d4cbca04a6221c37b78a56d4620d254") -- v0.4.17 发版（tag 同 commit）  2026-10-20
    -- 0.4.18 = MethodEditor（从零建方法门面，PR #9）+ MethodParameters 接收者行放行（PR #11）。
    add_versions("0.4.18", "ada334a12ec875ca9769bd5d4cb1f7e8494d2ebd") -- PR #11 合入 main 头  2026-10-26

    -- libca modules 对齐消费项目（mjbase/mjt）LUIOX_LIBCA_MODULES 家族统一
    -- 超集：包定义 add_deps 不吃消费方 requireconfs（实测），更小模块集会让
    -- 消费图多出一个 libca 实例（链接闭包多条 -libpath）。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})

    on_load(function (package)
        package:add("links", "libjbc")
        -- 语言标准传导：公开头使用 C++17（同 libjstr/libjclassfile 包口径）。
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
            -- 公开头含 UTF-8 中文注释，on_test 探针（has_cxxincludes/
            -- check_cxxsnippets 只吃这里的 cxxflags）在 GBK ACP 机器上按 GBK
            -- 读源会把注释吞行致 C2059 级联，安装失败——必须显式 /utf-8。
            package:add("cxxflags", "/utf-8")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        -- 包安装只装库本体：unittest/demo 均为开发态目标。
        import("package.tools.xmake").install(package, {with_tests = false})
        -- v0.1.0 布局归位：工程 headerfiles 模式 src/jbc/(**.hpp) 的括号组把
        -- jbc/ 前缀剥掉了，沙箱产物是 include/{jbc.hpp,core/,ir/,...} 平铺
        -- 布局，公开头的 #include "jbc/..." 解不到。这里整体搬回 include/jbc/
        -- 下；include/jbc 已存在（上游未来修正了布局）则跳过。附带摘掉误入
        -- 安装面的 test_helper（开发态测试基建，非交付物）。
        local includedir = path.join(package:installdir(), "include")
        if not os.isdir(path.join(includedir, "jbc")) then
            local staged = path.join(includedir, "jbc")
            os.mkdir(staged)
            -- consumer/ 自 0.4.16 起才进安装面，旧版本词条无此目录。
            for _, entry in ipairs({"jbc.hpp", "analysis", "consumer", "core", "ir", "type"}) do
                local src = path.join(includedir, entry)
                if os.isfile(src) or os.isdir(src) then
                    os.mv(src, path.join(staged, entry))
                end
            end
        end
        os.tryrm(path.join(package:installdir(), "lib", "test_helper.lib"))
        os.tryrm(path.join(package:installdir(), "lib", "libtest_helper.a"))
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("jbc/jbc.hpp", {configs = {languages = "cxx17"}}))
        -- 链接级自检：get_lib_version 强制解析 libjbc + libca 的符号链
        -- （缺任一环即在此暴露）。
        assert(package:check_cxxsnippets({test = [[
            #include "jbc/jbc.hpp"
            int main(int argc, char** argv) {
                return jbc::get_lib_version() != nullptr && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
package_end()
