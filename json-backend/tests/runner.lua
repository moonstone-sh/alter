package.path = "src/?.lua;src/?/init.lua;../host/src/?.lua;../host/src/?/init.lua;../host/?.lua;../host/?/init.lua;tests/?.lua;" .. package.path

local passed = 0
local failed = 0
local errors = {}
local current_suite = ""

function describe(name, fn)
    current_suite = name
    print("\n--- " .. name .. " ---")
    fn()
end

function it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        print("  ✗ " .. name)
        table.insert(errors, "[" .. current_suite .. "] " .. name .. ":\n    " .. tostring(err))
    end
end

function assert_equal(actual, expected, msg)
    if actual ~= expected then
        error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

function assert_true(cond, msg)
    if not cond then
        error(msg or "Expected true, got false/nil", 2)
    end
end

function assert_false(cond, msg)
    if cond then
        error(msg or "Expected false, got true", 2)
    end
end

function assert_nil(val, msg)
    if val ~= nil then
        error(msg or ("Expected nil, got " .. tostring(val)), 2)
    end
end

function assert_not_nil(val, msg)
    if val == nil then
        error(msg or "Expected non-nil value", 2)
    end
end

function assert_match(str, pattern, msg)
    if type(str) ~= "string" or not str:find(pattern) then
        error(msg or (string.format("Expected string '%s' to match pattern '%s'", tostring(str), pattern)), 2)
    end
end

function assert_error(fn, msg)
    local ok, err = pcall(fn)
    if ok then
        error(msg or "Expected function to raise error", 2)
    end
end

local function run_spec(spec_path)
    local ok, mod = pcall(require, spec_path)
    if not ok then
        failed = failed + 1
        table.insert(errors, "[Load Failure] " .. spec_path .. ":\n    " .. tostring(mod))
        print("  ✗ Failed to load " .. spec_path .. ": " .. tostring(mod))
        return
    end
    if type(mod) == "table" and type(mod.run) == "function" then
        describe(spec_path, function()
            local res = mod.run()
        end)
    end
end

local specs = {
    "conformance_spec",
    "json_specific_spec",
    "isolation_spec",
}

print("=== Running Alter JSON Backend Test Suites ===")
for _, sp in ipairs(specs) do
    run_spec(sp)
end

print(string.format("\nSummary: %d Passed, %d Failed", passed, failed))
if failed > 0 then
    print("\nFailures:")
    for _, err in ipairs(errors) do
        print(err)
    end
    os.exit(1)
else
    print("All tests in Alter JSON Backend Test Suites passed successfully!\n")
end
