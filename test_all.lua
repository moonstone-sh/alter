package.path = "host/src/?.lua;host/src/?/init.lua;host/?.lua;host/?/init.lua;host/contracts/?.lua;host/contracts/?/init.lua;host/tests/?.lua;json-backend/src/?.lua;json-backend/src/?/init.lua;json-backend/tests/?.lua;jsonc-backend/src/?.lua;jsonc-backend/src/?/init.lua;toml-backend/src/?.lua;toml-backend/src/?/init.lua;toml-backend/tests/?.lua;tests/?.lua;host/.moonstone/env/share/lua/5.4/?.lua;host/.moonstone/env/share/lua/5.4/?/init.lua;../valua/src/?.lua;../valua/src/?/init.lua;" .. package.path

print("==========================================================")
print("             RUNNING ALL ALTER TEST SUITES                ")
print("==========================================================")

-- Helper test runner
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

print("=== 1. Alter Host Specs ===")
run_spec("host.document_spec")
run_spec("host.navigation_spec")
run_spec("host.conflict_spec")
run_spec("contracts.schemas_spec")
run_spec("contracts.luacats_sync_spec")
run_spec("isolation.runtime_dep_spec")

print("\n=== 2. JSON Backend Specs ===")
run_spec("json-backend.tests.conformance_spec")
run_spec("json-backend.tests.json_specific_spec")
run_spec("json-backend.tests.isolation_spec")

print("\n=== 3. TOML Backend Specs ===")
run_spec("toml-backend.tests.conformance_spec")
run_spec("toml-backend.tests.toml_specific_spec")
run_spec("toml-backend.tests.isolation_spec")

print("\n=== 3b. JSONC Backend Specs ===")
do
    local ok, err = pcall(dofile, "jsonc-backend/tests/runner.lua")
    if not ok then
        failed = failed + 1
        table.insert(errors, "[JSONC Backend] " .. tostring(err))
        print("  ✗ JSONC backend: " .. tostring(err))
    end
end

print("\n=== 4. Mission Scenario Integration Test (.luarc.json & moonstone.toml) ===")
local alter = require("alter")
local json = require("alter_json")
local toml = require("alter_toml")

describe("End-to-End Real Document Mutations", function()
    it("mutates .luarc.json idempotently", function()
        local luarc_sample = '{\n  "workspace": {}\n}\n'
        local luarc_doc = alter.parse(luarc_sample, json)

        luarc_doc:at("runtime")
           :ensure_object()
           :at("plugin")
           :set("/path/to/plugin.lua")

        luarc_doc:at("workspace")
           :ensure_object()
           :at("library")
           :ensure_array()
           :append_unique("/path/to/lib")

        local res1 = luarc_doc:commit()
        assert_true(res1.changed)
        assert_match(res1.text, "/path/to/plugin.lua")
        assert_match(res1.text, "/path/to/lib")

        -- Second run on result text
        local luarc_doc2 = alter.parse(res1.text, json)
        luarc_doc2:at("runtime")
           :ensure_object()
           :at("plugin")
           :set("/path/to/plugin.lua")

        luarc_doc2:at("workspace")
           :ensure_object()
           :at("library")
           :ensure_array()
           :append_unique("/path/to/lib")

        local res2 = luarc_doc2:commit()
        assert_false(res2.changed, "Second commit must report changed = false")
        assert_equal(res2.bytes_written, 0, "No bytes written on idempotent second run")
    end)

    it("mutates moonstone.toml preserving comments and structure idempotently", function()
        local toml_sample = '# Manifest\n[package]\nname = "my-lib"\nversion = "0.1.0"\n\n[dependencies]\n'
        local doc = alter.parse(toml_sample, toml)

        doc:at("dependencies", "moonstone/valua"):set("^0.2.2")
        doc:at("package", "version"):set("0.2.0")

        local res1 = doc:commit()
        assert_true(res1.changed)
        assert_match(res1.text, "# Manifest")
        assert_match(res1.text, 'version = "0.2.0"')
        assert_match(res1.text, 'moonstone/valua = "%^0.2.2"')

        -- Second run on result text
        local doc2 = alter.parse(res1.text, toml)
        doc2:at("dependencies", "moonstone/valua"):set("^0.2.2")
        doc2:at("package", "version"):set("0.2.0")

        local res2 = doc2:commit()
        assert_false(res2.changed, "Second commit must report changed = false")
        assert_equal(res2.bytes_written, 0)
    end)
end)

print(string.format("\n=========================================================="))
print(string.format("Summary: %d Passed, %d Failed", passed, failed))
if failed > 0 then
    print("\nFailures:")
    for _, err in ipairs(errors) do
        print(err)
    end
    print("==========================================================")
    os.exit(1)
else
    print("==========================================================")
    print("           ALL ALTER WORKSPACE TESTS PASSED               ")
    print("==========================================================")
end
