-- Test changed packages of luiox-repo (create a scratch project, register this
-- repository as a path repo, then `xmake require --info/--check/--build` the
-- modified packages).
--
-- Adapted from xmake-io/xmake-repo scripts/test_packages.lua (Apache License
-- 2.0, https://github.com/xmake-io/xmake-repo/blob/dev/scripts/test_packages.lua).
--
-- Adaptations for luiox-repo:
--   * diff base comes from LUIOX_DIFF_BASE (CI passes the push/PR base commit),
--     falling back to HEAD^ and finally to testing everything when git diff
--     is unavailable;
--   * no `remote`/service support (packages clone their sources over https);
--   * platform filtering runs before `require --info` so a windows-only
--     package never fails the linux job (and vice versa);
--   * per-package extra configs: uikit's duilib layer is windows-only, so
--     uikit is required with core_only=true on linux/macosx;
--   * default fallback package when nothing changed: libca (xmake-repo uses
--     "tbox dev"; libca is the root dependency of every package here).

-- imports
import("core.base.option")
import("core.platform.platform")
import("core.package.package", {alias = "core_package"})
import("packages", {alias = "get_packages"})

-- the options (trimmed from xmake-repo; add toolchain/sdk options back as needed)
local options =
{
    {'v', "verbose",     "k",  nil, "Enable verbose information."              }
,   {'D', "diagnosis",   "k",  nil, "Enable diagnosis information."            }
,   {nil, "shallow",     "k",  nil, "Only install the root packages."          }
,   {'k', "kind",        "kv", nil, "Enable static/shared library."            }
,   {'p', "plat",        "kv", nil, "Set the given platform."                  }
,   {'a', "arch",        "kv", nil, "Set the given architecture."              }
,   {'m', "mode",        "kv", nil, "Set the given mode."                      }
,   {'j', "jobs",        "kv", nil, "Set the build jobs."                      }
,   {'f', "configs",     "kv", nil, "Set the configs."                         }
,   {'d', "debugdir",    "kv", nil, "Set the debug source directory."          }
,   {nil, "policies",    "kv", nil, "Set the policies."                        }
,   {nil, "runtimes",    "kv", nil, "Set the runtimes."                        }
,   {nil, "vs_runtime",  "kv", nil, "Set the vs runtime."                      }
,   {nil, "fetch",       "k",  nil, "Only fetch packages."                     }
,   {nil, "precompiled", "k",  nil, "Use precompiled packages."                }
,   {nil, "linkjobs",    "kv", nil, "Set the link jobs."                       }
,   {nil, "cflags",      "kv", nil, "Set the cflags."                          }
,   {nil, "cxxflags",    "kv", nil, "Set the cxxflags."                        }
,   {nil, "ldflags",     "kv", nil, "Set the ldflags."                         }
,   {nil, "packages",    "vs", nil, "The package list."                        }
}

-- check package is supported? (does this xmake version support on_check?)
function _check_package_is_supported()
    for _, names in pairs(core_package.apis()) do
        for _, name in ipairs(names) do
            if type(name) == "string" and name == "package.on_check" then
                return true
            end
        end
    end
end

-- config packages (scratch test project)
function _config_packages(argv)
    local config_argv = {"f", "-c"}
    if argv.verbose then
        table.insert(config_argv, "-v")
    end
    if argv.diagnosis then
        table.insert(config_argv, "-D")
    end
    if argv.plat then
        table.insert(config_argv, "--plat=" .. argv.plat)
    end
    if argv.arch then
        table.insert(config_argv, "--arch=" .. argv.arch)
    end
    if argv.mode then
        table.insert(config_argv, "--mode=" .. argv.mode)
    end
    if argv.policies then
        table.insert(config_argv, "--policies=" .. argv.policies)
    end
    local runtimes = argv.runtimes or argv.vs_runtime
    if runtimes then
        table.insert(config_argv, "--runtimes=" .. runtimes)
    end
    if argv.cflags then
        table.insert(config_argv, "--cflags=" .. argv.cflags)
    end
    if argv.cxxflags then
        table.insert(config_argv, "--cxxflags=" .. argv.cxxflags)
    end
    if argv.ldflags then
        table.insert(config_argv, "--ldflags=" .. argv.ldflags)
    end
    os.vexecv(os.programfile(), config_argv)
end

-- per-package extra configs: packages whose non-default configs are required
-- on some platforms (uikit's duilib layer is windows-only, so the core-only
-- engine must be selected everywhere else)
function _package_extra_configs(argv, packagename)
    local configs = {}
    local name = packagename:split("%s+")[1]
    if name == "uikit" and (argv.plat or os.subhost()) ~= "windows" then
        configs.core_only = true
    end
    return configs
end

-- get extra string for one package (mode/shared + package-specific configs)
function _get_extra_str(argv, packagename)
    local extra = {}
    if argv.mode == "debug" then
        extra.debug = true
    end
    -- Some packages set shared=true as default, so we need to force set
    -- shared=false to test static build.
    extra.configs = extra.configs or {}
    extra.configs.shared = argv.kind == "shared"
    table.join2(extra.configs, _package_extra_configs(argv, packagename))
    local configs = argv.configs
    if configs then
        extra.system = false
        local extra_configs, errors = ("{" .. configs .. "}"):deserialize()
        if extra_configs then
            table.join2(extra.configs, extra_configs)
        else
            raise(errors)
        end
    end
    return string.serialize(extra, {indent = false, strip = true})
end

-- group packages by their extra config string (packages with different
-- per-package configs need separate `xmake require` invocations)
function _group_packages(argv, packages)
    local groups = {}
    for _, package in ipairs(packages) do
        local extra_str = _get_extra_str(argv, package)
        groups[extra_str] = groups[extra_str] or {}
        table.insert(groups[extra_str], package)
    end
    return groups
end

-- load packages
function _load_packages(argv, packages)
    _config_packages(argv)
    local info_argv = {"require", "-f", "-y", "--info"}
    if argv.verbose then
        table.insert(info_argv, "-v")
    end
    if argv.diagnosis then
        table.insert(info_argv, "-D")
    end

    -- call `xmake require --info` to test on_load
    if #packages > 0 then
        print("testing to load packages ...")
        print("  > if it causes errors, please remove assert/raise() to on_check.")
        for extra_str, group in pairs(_group_packages(argv, packages)) do
            os.vexecv(os.programfile(), table.join(info_argv, "--extra=" .. extra_str, group))
        end
    end
end

-- require packages
function _require_packages(argv, packages)
    _config_packages(argv)
    local require_argv = {"require", "-f", "-y"}
    local check_argv = {"require", "-f", "-y", "--check"}
    if not argv.precompiled then
        table.insert(require_argv, "--build")
    end
    if argv.verbose then
        table.insert(require_argv, "-v")
        table.insert(check_argv, "-v")
    end
    if argv.diagnosis then
        table.insert(require_argv, "-D")
        table.insert(check_argv, "-D")
    end
    local is_debug = false
    if argv.debugdir then
        is_debug = true
        table.insert(require_argv, "--debugdir=" .. argv.debugdir)
    end
    if argv.shallow or is_debug then
        table.insert(require_argv, "--shallow")
    end
    if argv.jobs then
        table.insert(require_argv, "--jobs=" .. argv.jobs)
    end
    if argv.linkjobs then
        table.insert(require_argv, "--linkjobs=" .. argv.linkjobs)
    end
    if argv.fetch then
        table.insert(require_argv, "--fetch")
    end

    -- test on_check
    local install_packages = {}
    if _check_package_is_supported() then
        print("testing to check packages ...")
        for _, package in ipairs(packages) do
            local check_argv_package = table.join(check_argv, "--extra=" .. _get_extra_str(argv, package), package)
            local ok = os.vexecv(os.programfile(), check_argv_package, {try = true})
            if ok == 0 then
                table.insert(install_packages, package)
            end
        end
    else
        install_packages = packages
    end

    -- test installation
    if #install_packages > 0 then
        print("testing to install packages ...")
        for extra_str, group in pairs(_group_packages(argv, install_packages)) do
            os.vexecv(os.programfile(), table.join(require_argv, "--extra=" .. extra_str, group))
        end
    else
        print("no testable packages on %s or you're using lower version xmake!", argv.plat or os.subhost())
    end
end

-- the given package is supported?
function _package_is_supported(argv, packagename)
    local packages = get_packages()
    if packages then
        local plat = argv.plat or os.subhost()
        local packages_plat = packages[plat]
        for _, package in ipairs(packages_plat or {}) do
            if package and packagename:split("%s+")[1] == package.name then
                local arch = argv.arch
                if not arch and plat ~= os.subhost() then
                    arch = table.wrap(platform.archs(plat))[1]
                end
                if not arch then
                    arch = os.subarch()
                end
                for _, package_arch in ipairs(package.archs) do
                    if arch == package_arch then
                        return true
                    end
                end
            end
        end
    end
end

-- append "pkgname version" parsed from an add_versions diff line
function append_package_version(packages, line)
    local version = line:match("add_versions%(['\"](.-)['\"]") or line:match("package:add%(['\"]versions['\"],%s*['\"](.-)['\"]")
    if version then
        if version:find(":", 1, true) then
            version = version:split(":")[2]
        end
        if #packages > 0 and version then
            local lastpackage = packages[#packages]
            local splitinfo = lastpackage:split("%s+")
            table.insert(packages, splitinfo[1] .. " " .. version)
        end
    end
end

-- diff bases to try: LUIOX_DIFF_BASE (set by CI to the push/PR base commit)
-- first, then HEAD^ as the local/fallback base
function _diff_bases()
    local bases = {}
    local base = os.getenv("LUIOX_DIFF_BASE")
    if base then
        base = base:trim()
        -- an all-zero sha means the push has no previous commit
        if base ~= "" and not base:match("^0+$") then
            table.insert(bases, base)
        end
    end
    if not table.contains(bases, "HEAD^") then
        table.insert(bases, "HEAD^")
    end
    return bases
end

-- get modified packages; returns nil when git diff is not available
function get_modified_packages()
    local diff
    for _, base in ipairs(_diff_bases()) do
        diff = try {function () return os.iorun("git --no-pager diff " .. base) end}
        if diff then
            break
        end
    end
    if not diff then
        return nil
    end
    local new_packages = {}
    local old_packages = {}
    for _, line in ipairs(diff:split("\n")) do
        if line:startswith("+++ b/") then
            local file = line:sub(7)
            if file:startswith("packages") and not file:endswith("README.md") then
                assert(file == file:lower(), "%s must be lower case!", file)
                local package = file:match("packages/%w/(%S-)/")
                table.insert(new_packages, package)
                table.insert(old_packages, package)
            end
        elseif line:startswith("+") and (line:find("add_versions", 1, true) or line:find("package:add%((['\"])versions%1")) then
            append_package_version(new_packages, line)
        elseif line:startswith("-") and (line:find("add_versions", 1, true) or line:find("package:add%((['\"])versions%1")) then
            append_package_version(old_packages, line)
        end
    end
    if #old_packages > 0 then
        table.remove_if(old_packages, function (_, package)
            local splitinfo = package:split("%s+")
            return #splitinfo == 1
        end)
        table.remove_if(new_packages, function (_, package)
            return table.contains(old_packages, package)
        end)
        -- {
        --     "pkgname", <-- remove this
        --     "pkgname pkgver"
        -- }
        for i = #new_packages - 1, 1, -1 do
            if new_packages[i + 1]:startswith(new_packages[i] .. " ") then
                table.remove(new_packages, i)
            end
        end
    end
    return table.unique(new_packages)
end

-- all packages in the repository (fallback when the diff is unavailable)
function get_all_packages()
    local packages = {}
    for _, packagedir in ipairs(os.dirs(path.join("packages", "*", "*"))) do
        table.insert(packages, path.filename(packagedir))
    end
    table.sort(packages)
    return packages
end

-- the main entry
function main(...)

    -- parse arguments
    local argv = option.parse({...}, options, "Test all the given or changed packages.")

    -- get packages (still at the repository root, required by git and packages/)
    local packages = argv.packages or {}
    if #packages == 0 then
        packages = get_modified_packages()
        if not packages then
            print("warning: git diff is not available, testing all packages ...")
            packages = get_all_packages()
        end
    end
    if #packages == 0 then
        -- nothing changed: smoke-test the root package
        -- (xmake-repo uses "tbox dev" for the same purpose)
        table.insert(packages, "libca")
    end

    -- drop packages that are not supported on the current platform
    for idx, package in irpairs(packages) do
        assert(package == package:lower(), "package(%s) must be lower case!", package)
        if not _package_is_supported(argv, package) then
            table.remove(packages, idx)
        end
    end

    -- no testable packages
    if #packages == 0 then
        print("no testable packages on %s!", argv.plat or os.subhost())
        return
    end

    -- prepare test project
    local repodir = os.curdir()
    local workdir = path.join(os.tmpdir(), "luiox-repo")
    print(packages)
    os.setenv("XMAKE_STATS", "false")
    if not os.isfile(path.join(workdir, "test", "xmake.lua")) then
        os.tryrm(workdir)
        os.mkdir(workdir)
        os.cd(workdir)
        os.execv(os.programfile(), {"create", "test"})
    else
        os.cd(workdir)
    end
    os.cd("test")
    print(os.curdir())
    os.execv(os.programfile(), {"repo", "--add", "local-repo", repodir})
    os.execv(os.programfile(), {"repo", "-l"})

    -- test on_load (require --info), then on_check/on_install
    _load_packages(argv, packages)
    _require_packages(argv, packages)
end

return main
