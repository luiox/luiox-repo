-- mjbase 包定义（本仓只存定义，源码来自 github.com/luiox/mjbase）
--
-- 机制同 libjbytecode：add_urls 指向 git 仓库 + add_versions 第二参数锁 commit。
-- 发版/升级：在 mjbase 仓库定版后于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改）；消费项目自行择机升级。
--
-- 链接说明：包导出单库 mjbase。公开头跨模块伞头在 src/mjbase 根
-- （keys.hpp / i18n.hpp / util.hpp），模块目录头（hierarchy/spi/asm/…）随
-- src 一并导出；翻译文案表已内嵌进库本体（cli ArgParser 单源无下游覆盖时兜底）。
--
-- 消费方自备依赖（不在本包 add_deps 面，各自内联/源内目标；须与安装构建
-- 闭包一致避免实例分裂）：
--   - libjstd / libjhasm / libjblw / libjdk_finder：morpher 仓内已有 shim/
--     源目标；mjbase 的 jasm 文本面沿 libjhasm→libjblw→libjbytecode 链解析
--     （jhasm/jblw 为源仓链接层传递边，包面不显式声明）。
--
-- 包级显式依赖（与源仓根 xmake.lua require 清单一字面对齐，消实例分裂）：
--   - libca 0.0.16 统一超集 modules；libjstr / libjzip / libgarena + libjclassfile
--   - 版本门控（on_load）：0.0.5 起 libjbc >=0.4.22 裸下界对齐源仓实钉
--     （0.4.23 系上游仓库清理批无功能差异，libjhasm 0.3.3 沙箱内联词条只到
--     0.4.22）+ libjstd/libjhasm；0.0.7 起新增 sqlite3 3.53.0（analysis_db
--     存储引擎，PR #117）；0.0.3–0.0.4 libjbc 0.4.23 + libjstd/libjhasm
--     （libjbytecode 随 mjbase main 旧栈出清剜除）；0.0.2 及以前 libjbc
--     0.4.15 + libjbytecode
--   - libarchive 3.8.8（openssl3=false）仅 0.0.4 及以前：model 资源解包
--     后端，安装期在包沙箱内经源仓 mjbase-repo 本地覆盖仓自足构建；0.0.5
--     起解包面随 PR #112 下沉消费方，包面不再携带。
--
-- 包级验证以首个消费方（morpher mjt-dump 换轨批次）实际 add_requires 为准。

package("mjbase")
    set_homepage("https://github.com/luiox/mjbase")
    set_description("Cross-class JVM program analysis & transformation base on libjbc (keys/hierarchy/asm/pass pipeline; git direct package)")
    set_license("MIT")

    add_urls("https://github.com/luiox/mjbase.git")

    -- 语义版本名 + 锁定 commit。版本条目只追加、不修改。
    -- 0.0.1 = 首个独立仓发版（268 源文件；morpher 仓内副本的 air/sir deobf IR
    -- 按归属裁决不入 mjbase，随 mjt-deobf 持有）。测试面含救回的 keys/i18n/util
    -- 第 5 批孤儿测试（Windows 本机预存 4 例 storeLock* 红不计入其它平台）。
    add_versions("0.0.1", "31e6e7f304a524e7a2e0e41e0e474833905e96d0") -- 首发基线 + 孤儿测试面救回 + 导出捕获修正 2026-10-19
    add_versions("0.0.2", "f87aa3e0bffdd62996a59bc7cdddfeb69a6bd0ae") -- i18n 生成头回源（导出面补齐生成件，on_test 加 mjbase/i18n.hpp 直验）2026-10-19
    add_versions("0.0.3", "b3dc748f0efa6199f409c82018d0e850e758bf9e") -- workspace 退役 + hierarchy/asm_analyzer 帧查询面（FrameQuery）+ spi 重组（common_super_resolver/frame_rewire 归 spi）；依赖变阵：libjbytecode 剜除、libjbc 0.4.15→0.4.23、新增 libjstd/libjhasm 2026-10-29
    add_versions("0.0.4", "4d7dcc6d0d9d8046596e9a9f9f5a1311953517c3") -- jasm 孤立代理反汇编回归 + libjhasm 0.3.3 接线（混淆语料 CESU-8 孤立代理不再一票否决）2026-10-29
    add_versions("0.0.5", "9b34b34cc9cba50b2a9e810d1b1387badc8a9d9b") -- libarchive 死面摘除：resource_io 解包面随需求下沉消费方，包面依赖同步退场 + libjbc 下界对齐实钉 0.4.22（main，PR #112）2026-10-30
    add_versions("0.0.6", "1b80687921c09d7d82121665616832f97cdc959b") -- shadow 表 rename 后 rebind（PR #113）+ libgarena 0.0.3→0.0.5 / libjdk_finder 0.1.0→0.1.1（PR #114；main tip 定版，包源自带 requires，词条面无新增）2026-10-31
    add_versions("0.0.7", "ecbe15054c838eaaf88d35cdf7a20cb023c9a145") -- analysis-db 特性线合入（PR #117）：project/analysis_db 分析数据库 + 四 pass（局部变量表规范化/行号清理/入口槽置换还原注册面）+ renamer/shadow_alias_store；依赖变阵：新增 sqlite3 3.53.0（analysis_db 存储引擎）2026-11-01
    add_versions("0.0.8", "540f156d4e60c98626ecddc878034ac4e5b47d1b") -- analysis-db schema v3 条目身份层（PR #122）：inputs/entries 表（entry_id 单调只增不删、(input_id,path,sha256) 锚匹配、墓碑保留与原地复活、entries_live 部分唯一索引）+ classes.entry_id 链接 + ingest/ensureInput 批量登记面 + 旧库 fail-loud 版本门；词条面无新增依赖 2026-11-01
    add_versions("0.0.9", "67d706fa7cedce45fd8bfcf2b2c170d7ad0d8726") -- LVT 显示名策略（PR #124）：analysis/lvt_display_policy 纯函数判定面（可信名逐字节扫描 / var<槽位> 呈现与 cat2 跳号 / 同槽多类型后缀与畸形 t<n> 兜底 / jar 级 1/2 阈值兜底），只作用显示层不改字节码不建表；词条面无新增依赖 2026-11-01
    add_versions("0.0.10", "265f1cf76ed8b58dd20b134c87c7fd5a5fcd3cfa") -- mask 出口遮蔽层（PR #126，#121 §4.5）：mask_regex_engine（std::regex 单点适配，长度门/模式门）/mask_suspect（字节级对抗扫描）/mask_evaluator（优先级判定序、suspect 压过 allow、信任级别默认）+ schema v4（mask_rules 表 + meta 信任级别，旧 v3 库 fail-loud）；analysis-db 性能调优（PR #128，#121 B6）：打开面 PRAGMA（cache 256MB/temp_store/synchronous NORMAL）+ refs_source_class 索引 + 按源反查两步走，实测整库导入 2.6-3.0×、按源反查 150-320×；词条面无新增依赖 2026-11-01
    add_versions("0.0.11", "305bbe83cd0665e467cdbfea1018a456a9fd89d1") -- 类普查投影（PR #131，#121 B4 / mjt #39）：project/census 查询面（censusClasses 类事实 JOIN 条目 byte_size/regular + 接口与成员计数相关子查询聚合、ORDER BY internal_name BINARY 确定序；censusContainer 条目活跃/墓碑与 regular 二分 + entries.kind 分布 + 路径形态 facet 分布 + 类/成员/引用计数）+ entry_shape 条目路径形态判定公共面（facet 枚举、固定优先序、B1 regular 口径上提零漂移）+ class_kind 类形态分类（access+super 派生不存储，Module>Annotation>Interface>Enum>Record>Class 取先）+ mapping \uXXXX 转义增补平面补全（代理对出码/配对重组，escape→unescape 全码位域往返闭合）；词条面无新增依赖
    add_versions("0.0.12", "d57e9410fbcbca614588555fc033cd2cfbc2b6ba") -- entry_shape 补 Overlong/WhitespaceEdge 两 facet（PR #136，#121 P1）：空格名混淆 jar 实测（全空格路径 21845B）暴露 B1 最小口径漏判空白与超长形态，补单段 >255B 或全路径 >4096B 的 Overlong 与段首尾空格的 WhitespaceEdge，优先序 TrailingSlash 之后，历史库重导入 regular 翻转属预期；词条面无新增依赖 2026-11-02
    add_versions("0.0.13", "1e193c2addaae9cae16af201987b640cce34a824") -- 按源成员引用切片替换（PR #139，#121 G1：replaceReferencesFromMember 单事务按 source_member_id 删+插，切片身份先落定、行内 source 一致性 Invalid 门，空输入清切片）+ 库前缀分类核心（PR #140，#132 L1：library_origin 官方 10 + 第三方 16 段边界前缀表，'/ '锚防误吸，规则版本常量）+ 引用与层次闭包分页变体（PR #141，#121 G4：7 查询 *Paged 行偏移窗口，窗口语义契约化，闭包成本说明）+ censusClasses origin 派生列（PR #142，#132 L1 接线：行级来源切面，零 schema 变更）；词条面无新增依赖 2026-11-03
    add_versions("0.0.14", "70386d5faf83e5dd38ecb39ca439ca319fac1ae7") -- refs 目标侧 id 化（PR #149，#121 P5 / #138 schema v5：refs 加 target_class_id/target_member_id 可空外键，applyReferenceBatch 双 target memo 整目标二元化落 id/文本、referencesTo* 双分支 UNION ALL 按 ref_id 互斥不重不漏、kReferenceSelectSql 双 LEFT JOIN + COALESCE、source 侧两索引沿用、目标文本字节 API 读写抗非法 UTF-8 名、版本门 v4 拒绝可诊断；混淆语料 PoC 实测 373.8MB→8.74MB，切片查询 6×、类目标页扫 155×）；词条面无新增依赖 2026-11-04
    add_versions("0.0.15", "59ffe5d882126735d6ab36b94a1b6b994a6e099a") -- member 普查投影面（PR #150，#148 设计批 1：DbMemberCensusRow 一行一成员 + censusMembers(inputId) 可见域与墓碑语义同 censusClasses、复合键 BINARY 行序定死投影层、native 投影派生、origin 继承类级不重复分类；零 schema 变更）；词条面无新增依赖 2026-11-04
    add_versions("0.0.16", "7d5a41a57e312053bd64002405d1fcd2b45dc367") -- producer 注册表批 1-3（PR #151，#143 schema v6：producers/batches/batch_scopes 三表 + registerProducer/openBatch/closeBatch + renames 行级 producer_id + 事实写入口 batchId 首参必填参数化（0=无批落 NULL 归属）+ 归属解析双探针取大 + producerStats；旧 v5 库 fail-loud）；词条面无新增依赖 2026-11-04
    add_versions("0.0.17", "33b86af9c09469d22f3543181699fad741e65b6d") -- method_versions 方法版本指纹表（PR #154，#132 db 接线：schema v8，32 字节 BLOB + fp_version 算法版本列 + is_current 部分唯一索引当前指针，recordMethodVersion 幂等/批量原子/currentMethodFingerprint/listMethodVersions，旧 v7 库 fail-loud）；词条面无新增依赖 2026-11-04
    add_versions("0.0.18", "7999684fe7ef6343955f4d37a0784e29f7e9df94") -- jar 导入同名重复条目改末现保留对齐 JVM 类加载口径（PR #160，Dup 名以物理后现为准）+ asm/remapper 注解递归畸形输入边界守卫（#158）；词条面无新增依赖 2026-11-04
    add_versions("0.0.19", "07ef1a0d0db18b9b4cef414cb3e168399e5bd255") -- 全程序方法可达闭包入分析库（PR #162，#159：schema v8→v9 fail-loud，closure_batches/closure_members 两新表 + batches.kind 新词 closure_write，闭包计算面 project/reachability_closure——refs 主图整数对边 + 保守族展开 + clinit 首触沿 super 链 + 种子三档，失效 = 输入图指纹（inputs 投影 + 四表变更敏感聚合）+ seed_mask 双匹配整体重算，查询面 listClosureBatches/closureMembersPaged/isClosureMember/freshClosureBatch/closureGraphEdges；设计稿与 PoC 数字 PR #161）；词条面无新增依赖 2026-11-05
    add_versions("0.0.20", "7234306feb3ce57383bb74a07a1d763258a5c651") -- 真改名身份迁移（PR #198：AnalysisDb::migrateIdentities 单事务批量改写 classes.internal_name / members.name+descriptor（连带 super_name/interfaces 文本副本），class_id / member_id 与 renames 覆盖行零触碰——覆盖层按稳定 ID 键控，真改名后零补丁，undo 反向规格对称回滚；未命中跳过、撞名/批内重复 Invalid 整批回滚；shadow 落分析库的基座前提）+ jasm validate 语义级 flag 规则库（#193，16 条 JVMS/HotSpot 对齐规则 + JDK 对拍门）+ libjstr 0.0.4 / 文档树对齐（#196/#192/#197）；词条面无新增依赖 2026-11-08

    -- libca modules 对齐消费项目（morpher/mjbase）统一超集：包定义 add_deps
    -- 不吃消费方 requireconfs（实测），更小模块集会让消费图多出一个 libca
    -- 实例（链接闭包多条 -libpath）。
    add_deps("libca", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})
    add_deps("zlib")
    add_deps("libjstr")
    add_deps("libgarena")
    add_deps("libjzip")
    add_deps("libjclassfile")

    on_load(function (package)
        -- 依赖随版本变阵（0.0.3 起 mjbase main 剜除旧栈 libjbytecode、
        -- libjbc 升 0.4.23、jasm 文本面底座 libjstd/libjhasm 进包级显式依赖，
        -- 与源仓根 require 清单字面对齐消实例分裂）：既有条目只追加不修改，
        -- 旧版本保持原依赖集可继续安装。
        if package:version():ge("0.0.7") then
            package:add("deps", "libjbc >=0.4.22") -- 裸下界对齐源仓实钉 0.4.22（0.4.23 系上游清理批无功能差异，libjhasm 0.3.3 沙箱内联词条只到 0.4.22）
            package:add("deps", "libjstd 0.0.1")
            package:add("deps", "libjhasm >=0.3.3") -- 裸下界：孤立代理转义修复起（0.3.3）
            -- sqlite3：analysis_db（project 模块，PR #117）的存储引擎，配置
            -- 与源仓根 require 一致（静态链接）。
            package:add("deps", "sqlite3 3.53.0", {configs = {shared = false}})
        elseif package:version():ge("0.0.5") then
            package:add("deps", "libjbc >=0.4.22") -- 裸下界对齐源仓实钉 0.4.22（0.4.23 系上游清理批无功能差异，libjhasm 0.3.3 沙箱内联词条只到 0.4.22）
            package:add("deps", "libjstd 0.0.1")
            package:add("deps", "libjhasm >=0.3.3") -- 裸下界：孤立代理转义修复起（0.3.3）
            -- libarchive 随 PR #112 退场：resource_io 解包面下沉消费方，
            -- 0.0.5 起新代码无 archive_* 符号，包面不再携带（0.0.4 分支
            -- 保留旧修复不动，旧版本保持原依赖集可继续安装）。
        elseif package:version():ge("0.0.4") then
            package:add("deps", "libjbc >=0.4.23")
            package:add("deps", "libjstd 0.0.1")
            package:add("deps", "libjhasm >=0.3.3") -- 裸下界：孤立代理转义修复起（0.3.3）
            -- libarchive：model resource_io 的解包后端（源仓 target add_packages
            -- 私有挂载——包面漏声明让导出的 mjbase.lib 带未解析 archive_* 符号，
            -- 首个包消费方 grunt_cli 链接期实证后补）。
            package:add("deps", "libarchive 3.8.8", {configs = {openssl3 = false}})
        elseif package:version():ge("0.0.3") then
            package:add("deps", "libjbc >=0.4.23")  -- 裸下界：家族 libjbc 升版不被 mjbase 0.0.3 钉死（0.4.24 libca 0.0.16 统一实测兼容）
            package:add("deps", "libjstd 0.0.1")
            package:add("deps", "libjhasm 0.3.2")
        else
            package:add("deps", "libjbc 0.4.15")
            package:add("deps", "libjbytecode")
        end
        package:add("links", "mjbase")
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17")
            -- bcrypt：libca crypto NT 系。
            package:add("syslinks", "bcrypt")
            -- xmllite：包内 libarchive 静态成员的 xar 读符号（0.0.4 及以前的
            -- final link 需要，public 语义同源仓 target）；0.0.5 起源仓随
            -- libarchive 一并摘 xmllite syslinks，包面对齐不再携带。
            if package:version():lt("0.0.5") then
                package:add("syslinks", "xmllite")
            end
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        -- 包安装只装库本体：unittest 均为开发态目标。
        import("package.tools.xmake").install(package, {with_tests = false})
    end)

    on_test(function (package)
        -- 编译面自检：跨模块伞头 + 深目录头沿安装 include 根解析成功。
        -- i18n.hpp 直验仅 <0.0.3（i18n 面随 cli 退役整体剜除，main 已无此头）。
        assert(package:has_cxxincludes("mjbase/keys.hpp", {configs = {languages = "cxx17"}}))
        assert(package:has_cxxincludes("mjbase/hierarchy/class_hierarchy.hpp", {configs = {languages = "cxx17"}}))
        if package:version():lt("0.0.3") then
            assert(package:has_cxxincludes("mjbase/i18n.hpp", {configs = {languages = "cxx17"}}))
        else
            assert(package:has_cxxincludes("mjbase/util.hpp", {configs = {languages = "cxx17"}}))
        end
    end)
