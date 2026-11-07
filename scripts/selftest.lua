-- Self-test tier of the luiox-repo package test suite: for changed packages
-- registered in _selftests below, fetch the package's own source repository
-- at the commit pinned by the package entry's add_versions, build it with the
-- package's own xmake.lua, then run the registered test targets. A nonzero
-- exit code of any test binary fails the whole CI job (no warn-and-pass).
--
-- Why a fresh shallow clone instead of reusing the fetched source inside the
-- xmake package sandbox: the sandbox prunes fetched sources after install
-- unpredictably (measured: libjzip 0.0.3 keeps source/, 0.0.4 does not) and
-- its cache path embeds the xmake api version, so reuse is neither stable
-- across xmake upgrades nor guaranteed to exist on a restored CI cache.
-- clone + fetch-by-commit (GitHub serves arbitrary reachable shas) is
-- deterministic on every platform and always matches the pinned entry.
--
-- Everything the tier creates (clone, build tree, test output) lives under
-- <tmpdir>/luiox-repo-selftest/ and is wiped per package, pass or fail.

-- the self-test registry: package name -> {targets, flags}
--   targets = test binaries defined by the package's own xmake.lua (usually
--             behind a with_tests option); their exit code is the verdict
--   flags   = optional build flags forwarded to `xmake f`
--             (with_tests = true becomes --with_tests=y)
-- Wiring a new package is one line, e.g.:
--   libfoo = {targets = {"libfoo_unittest"}, flags = {with_tests = true}}
local _selftests =
{
    libjzip = {targets = {"libjzip_unittest", "libjzip_origintest"}, flags = {with_tests = true}}
}

-- names of all registered packages (sorted; used by test_packages.lua to
-- validate the registry itself whenever it changes)
function registered_packages()
    local names = {}
    for name, _ in pairs(_selftests) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- git proxy passthrough for local runs: CI reaches github.com directly and
-- needs nothing; locally set LUIOX_GIT_PROXY (e.g. socks5h://127.0.0.1:10809)
-- to reach github.com through a proxy
function _git_proxy_argv()
    local proxy = os.getenv("LUIOX_GIT_PROXY")
    if proxy and proxy:trim() ~= "" then
        return {"-c", "http.proxy=" .. proxy:trim(), "-c", "http.version=HTTP/1.1"}
    end
    return {}
end

-- fetch the pinned commit into srcdir: shallow clone without checkout, then
-- fetch the exact pinned commit and check it out (the remote default branch
-- may have advanced past the pinned entry in the meantime)
function _acquire_source_once(url, commit, srcdir)
    os.vexecv("git", table.join(_git_proxy_argv(), {"clone", "--no-checkout", "--depth", "1", url, srcdir}))
    os.vexecv("git", table.join({"-C", srcdir}, _git_proxy_argv(), {"fetch", "--depth", "1", "origin", commit}))
    os.vexecv("git", {"-C", srcdir, "checkout", "--force", "FETCH_HEAD"})
    -- guard the verdict: the working tree must sit exactly on the pinned commit
    -- (os.iorunv returns the stdout directly and raises on failure)
    local head = os.iorunv("git", {"-C", srcdir, "rev-parse", "HEAD"})
    assert(head and head:trim() == commit, "selftest: checked out %s but the package entry pins %s!", head and head:trim() or "?", commit)
end

-- acquisition with one retry: a dropped connection mid-clone is the one
-- transient failure this tier cannot rule out; the partial tree is wiped so
-- the second attempt starts clean
function _acquire_source(url, commit, srcdir)
    local ok = try
    {
        function ()
            _acquire_source_once(url, commit, srcdir)
            return true
        end
    }
    if not ok then
        print("selftest: source acquisition failed, retrying once ...")
        os.tryrm(srcdir)
        _acquire_source_once(url, commit, srcdir)
    end
end

-- registry flags -> xmake f options: with_tests = true -> --with_tests=y
function _flag_option(name, value)
    if value == true then
        return "--" .. name .. "=y"
    elseif value == false then
        return "--" .. name .. "=n"
    end
    return "--" .. name .. "=" .. tostring(value)
end

-- locate the built test binary: xmake's default layout is
-- build/<plat>/<arch>/<mode>/<target>[.exe]; fall back to a build/ scan so a
-- layout drift cannot silently skip the verdict
function _target_binary(srcdir, plat, arch, mode, target)
    local filename = target
    if plat == "windows" then
        filename = target .. ".exe"
    end
    local binary = path.join(srcdir, "build", plat, arch, mode, filename)
    if os.isfile(binary) then
        return binary
    end
    local candidates = os.files(path.join(srcdir, "build", "**", filename))
    if candidates and #candidates > 0 then
        return candidates[1]
    end
end

-- last add_versions entry of the package definition (newest pinned commit;
-- used when the diff entry carried no explicit version)
function _last_version(packagefile)
    local version
    for _, line in ipairs(io.readfile(packagefile):split("\n")) do
        local matched = line:match("add_versions%(['\"](.-)['\"]")
        if matched then
            version = matched
        end
    end
    return version
end

-- commit pinned for the given version in the package definition
function _version_commit(packagefile, version)
    local escaped = version:gsub("%.", "%%.")
    for _, line in ipairs(io.readfile(packagefile):split("\n")) do
        local commit = line:match("add_versions%(['\"]" .. escaped .. "['\"],%s*['\"](%w+)['\"]")
        if commit then
            return commit
        end
    end
end

-- first add_urls entry of the package definition (the source repository)
function _package_url(packagefile)
    for _, line in ipairs(io.readfile(packagefile):split("\n")) do
        local url = line:match("add_urls%(['\"](.-)['\"]")
        if url then
            return url
        end
    end
end

-- self-test one package end to end: clone at the pinned commit, build the
-- registered test targets with the package's own xmake.lua, run them
function _run_package(argv, name, version, repodir)
    local entry = _selftests[name]
    local packagefile = path.join(repodir, "packages", name:sub(1, 1), name, "xmake.lua")
    local url = _package_url(packagefile)
    local commit = _version_commit(packagefile, version)
    assert(url and commit, "selftest(%s): cannot resolve source url and pinned commit for version %s from %s", name, version, packagefile)

    local workdir = path.join(os.tmpdir(), "luiox-repo-selftest", name)
    print(format("selftest(%s): building %s @ %s (%s) ...", name, version, commit:sub(1, 7), url))
    -- xmake's try discards the catch handler's return values, so the failure
    -- travels out through this upvalue
    local failure = nil
    try
    {
        function ()
            os.tryrm(workdir)
            os.mkdir(workdir)
            local srcdir = path.join(workdir, "source")
            _acquire_source(url, commit, srcdir)

            -- the package source resolves its own dependencies (luiox family
            -- packages via the local-repo registration below, xrepo packages
            -- such as zlib/gtest via the builtin repositories)
            os.execv(os.programfile(), {"repo", "--add", "local-repo", repodir})
            os.cd(srcdir)
            local plat = argv.plat or os.subhost()
            local arch = argv.arch or os.subarch()
            local mode = argv.mode or "release"
            local config_argv = {"f", "-y", "--plat=" .. plat, "--arch=" .. arch, "--mode=" .. mode}
            if argv.jobs then
                table.insert(config_argv, "--jobs=" .. argv.jobs)
            end
            for flag, value in pairs(entry.flags or {}) do
                table.insert(config_argv, _flag_option(flag, value))
            end
            os.vexecv(os.programfile(), config_argv)
            -- xmake's build command takes a single positional target
            for _, target in ipairs(entry.targets) do
                os.vexecv(os.programfile(), {"-y", target})
            end

            -- the verdict: exit code of each registered test binary, run with
            -- the package project as cwd (mirrors the targets' set_rundir)
            for _, target in ipairs(entry.targets) do
                local binary = _target_binary(srcdir, plat, arch, mode, target)
                assert(binary, "selftest(%s): %s was not built under %s", name, target, path.join(srcdir, "build"))
                os.cd(srcdir)
                local exitcode, runerrors = os.execv(binary, {}, {try = true})
                if not exitcode or exitcode ~= 0 then
                    raise("selftest(%s): %s exited with code %s%s", name, target, exitcode or "?", runerrors and (", " .. runerrors) or "")
                end
                print(format("selftest(%s): %s passed", name, target))
            end
            return true
        end,
        catch
        {
            function (errs)
                failure = errs
            end
        }
    }
    -- the cwd may sit inside the workdir after a failure, which would block
    -- the wipe on windows; move back to the repository first
    os.cd(repodir)
    os.tryrm(workdir)
    if failure then
        -- normalize xmake's internal table error objects (e.g. from os.execv
        -- failures) so the raised error stays readable
        if type(failure) == "table" then
            failure = string.serialize(failure, {indent = false, strip = true})
        end
        raise(failure)
    end
end

-- the main entry: run the self-test tier for the changed package list
-- ("pkgname" / "pkgname version" entries, called by test_packages.lua after
-- the require/build tier)
function main(argv, packages, repodir)
    local tested = {}
    for _, packagename in ipairs(packages) do
        local name = packagename:split("%s+")[1]
        if _selftests[name] and not table.contains(tested, name) then
            local version = packagename:split("%s+")[2]
            if not version then
                local packagefile = path.join(repodir, "packages", name:sub(1, 1), name, "xmake.lua")
                version = _last_version(packagefile)
            end
            assert(version, "selftest(%s): no add_versions entry found in the package definition", name)
            table.insert(tested, name)
            _run_package(argv, name, version, repodir)
        end
    end
    if #tested > 0 then
        print(format("self-test tier done: %s", table.concat(tested, ", ")))
    else
        print("self-test tier: no registered package in the changed set, skip.")
    end
    -- the per-package workdirs are wiped as they finish; drop the tier root
    os.tryrm(path.join(os.tmpdir(), "luiox-repo-selftest"))
end

return main
