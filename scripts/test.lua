-- Entry point of the luiox-repo package test suite: decide from the changed
-- files whether package tests are needed, then delegate to test_packages.lua.
--
-- Adapted from xmake-io/xmake-repo scripts/test.lua (Apache License 2.0,
-- https://github.com/xmake-io/xmake-repo/blob/dev/scripts/test.lua).
--
-- Differences from xmake-repo: this repository has no templates directory;
-- besides packages/ a change under scripts/ or .github/ also triggers the
-- tests (so CI changes are validated by the very first run), while pure
-- documentation changes skip the build entirely (xmake-repo always runs its
-- "tbox dev" smoke test instead).

-- imports
import("test_packages")

-- diff base: CI passes LUIOX_DIFF_BASE (push base / PR base), else HEAD^
function _diff_base()
    local base = os.getenv("LUIOX_DIFF_BASE")
    if base then
        base = base:trim()
        -- an all-zero sha means the push has no previous commit
        if base == "" or base:match("^0+$") then
            base = nil
        end
    end
    return base or "HEAD^"
end

function main(...)
    local argv = table.pack(...)

    -- get modified files
    local run_packages = false
    local diff = try {function () return os.iorun("git --no-pager diff --name-only " .. _diff_base()) end}
    if diff then
        for _, file in ipairs(diff:split("\n")) do
            file = file:trim()
            if file:startswith("packages") or file:startswith("scripts") or file:startswith(".github") then
                run_packages = true
            end
        end
    else
        -- cannot determine what changed: run tests to be safe
        run_packages = true
    end

    -- run package tests
    if run_packages then
        print("Running package tests...")
        test_packages(table.unpack(argv))
    else
        print("No package or CI script changes detected, skip tests.")
    end
end
