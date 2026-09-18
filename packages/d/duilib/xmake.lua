-- duilib 包定义（本仓只存定义，源码来自 github.com/luiox/DuiLib_DuiEditor）
--
-- 机制：git 直连包，add_versions 锁 fork commit，与 libca/micon 同款。
-- fork 根 xmake.lua 自带 DuiLib target（默认 static、public includedirs、
-- UILIB_STATIC 处理、pugixml/nanosvg/stb 内部依赖齐备），on_install 指名
-- 构建该 target，fork 内部依赖随依赖图一并构建，不外泄。
--
-- 发版/升级：在 fork 定版后，于此文件 add_versions 追加新版本条目
-- （既有条目只追加不修改，见 README 可复现纪律）；消费项目自行择机升级。
--
-- 链接说明（静态库）：fork 的 DuiLib target 仅 shared 形态声明 add_syslinks，
-- 静态形态的系统依赖由本包按平台补齐（未用到的系统库由链接器自行裁剪，
-- 无副作用）。消费方须自行定义 UNICODE/_UNICODE/UILIB_STATIC——UIlib.h 按
-- UILIB_STATIC 选择导入语义，fork 只在 target 内部定义该宏，不对外传导。
--
-- ATL 门控：no_activex / no_imageboxex 透传 fork 的 DUILIB_NO_* 配置。
-- 注意极性：默认 false（ATL 功能编入，与 fork 原生行为一致）；需要裁剪的
-- 消费者显式传 true（xmake configs 显式传 false 不传导，默认侧须是无害侧）。

package("duilib")
    set_homepage("https://github.com/luiox/DuiLib_DuiEditor")
    set_description("DuiLib directui framework (DuiLib_DuiEditor fork, Win32 backend, git direct package)")
    set_license("BSD-2-Clause")

    add_urls("https://github.com/luiox/DuiLib_DuiEditor.git")

    -- 语义版本名 + 锁定 fork commit。版本条目只追加、不修改。
    -- 0.1.0 = 首个入包基线（mlaunch submodule 指针快照 03c53b2：pugixml 独立
    -- TU / nanosvg 接线 / ATL 门控收口态）。
    add_versions("0.1.0", "03c53b2ac73dbad25427b92eedd3d02112457ded")

    add_configs("no_activex", {description = "Define DUILIB_NO_ACTIVEX and exclude UIFlash/UIWebBrowser (ATL-free build).", default = false, type = "boolean"})
    add_configs("no_imageboxex", {description = "Define DUILIB_NO_IMAGEBOXEX and exclude UIImageBoxEx (ATL-free build).", default = false, type = "boolean"})

    -- fork 的 DuiLib target 仅 shared 形态声明系统库；静态消费方由本包补齐。
    if is_plat("windows", "mingw") then
        add_syslinks("User32", "Gdi32", "Comctl32", "Ole32", "OleAut32", "Imm32", "Winmm", "Version", "Uxtheme", "Advapi32", "Shell32", "Dwmapi")
        -- compat.h 的 Win32 分支由自定义宏 WIN32（非编译器预定义的 _WIN32）守卫，
        -- UIlib.h 按 UILIB_STATIC 选择导入语义——这些宏作为公开 define 随包传导，
        -- 消费方重复定义同值宏无副作用。
        add_defines("WIN32", "WINDOWS", "UNICODE", "_UNICODE", "UILIB_STATIC")
    end

    on_install("windows", function (package)
        local configs = {
            no_activex = package:config("no_activex"),
            no_imageboxex = package:config("no_imageboxex"),
        }
        import("package.tools.xmake").install(package, configs, {targets = "DuiLib"})
        -- fork 的 DuiLib target 未声明 add_headerfiles，公开头手动随包装。
        -- 必须保持子目录结构：UIlib.h 以相对路径拉起 Utils/Core/Control 等子目录头。
        local includedir = package:installdir("include")
        os.cp("DuiLib/*.h", includedir)
        for _, sub in ipairs({ "Core", "Control", "Layout", "Render", "Utils" }) do
            os.cp(path.join("DuiLib", sub, "*.h"), path.join(includedir, sub))
        end
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("UIlib.h", {configs = {defines = "WIN32,WINDOWS,UNICODE,_UNICODE,UILIB_STATIC", languages = "cxx17"}}))
        -- 链接级自检：取 CPaintManagerUI 静态成员函数地址，强制符号解析走静态库。
        assert(package:check_cxxsnippets({test = [[
            #include "UIlib.h"
            int main(int argc, char** argv) {
                auto f = &DuiLib::CPaintManagerUI::SetResourcePath;
                return f != nullptr && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {defines = "WIN32,WINDOWS,UNICODE,_UNICODE,UILIB_STATIC", languages = "cxx17"}}))
    end)
