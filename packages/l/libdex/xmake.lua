package("libdex")
    set_homepage("https://github.com/luiox/libdex")
    set_description("DEX read/write library with a lazy DexFile DOM and Smali assembly/disassembly")
    set_license("MIT")

    add_urls("https://github.com/luiox/libdex.git")
    -- Preserve the source revision already consumed by mjt's APK/DEX analysis.
    add_versions("0.0.1", "a5fae5a3c788d8d85bf32bd21633a84a9525927a")

    -- Match the source project's dependency versions and the family module set.
    add_deps("libca 0.0.16", {configs = {modules = "core,crypto,str,fs,env,io,json,net,http,process,opt,thread,log,zip,resources,i18n,test"}})
    add_deps("libjstr 0.0.4")
    add_deps("zlib")

    on_load(function (package)
        -- GNU ld must see the dependent Smali archive before the DEX archive.
        package:add("links", "libsmali", "libdex")
        if package:is_plat("windows") then
            package:add("cxxflags", "/std:c++17", "/utf-8")
        else
            package:add("cxxflags", "-std=c++17")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        import("package.tools.xmake").install(package, {with_tests = false})
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include "dex/dex.hpp"
            #include "smali/assemble.hpp"
            int main(int argc, char** argv) {
                auto file = dex::core::DexFile::createEmpty(35);
                if (!file || dex::get_lib_version() == nullptr) return 1;
                dex::smali::SmaliAssembler assembler(*file);
                auto assembled = assembler.assembleClass(
                    ".class public Lpackage/Test;\n"
                    ".super Ljava/lang/Object;\n");
                return assembled.is_ok() && argc >= 0 ? 0 : 1;
            }
        ]]}, {configs = {languages = "cxx17"}}))
    end)
