local v = require("valua")
local contracts = require("contracts")

local function run()
    local passed = 0
    local total = 0

    local function it(name, fn)
        total = total + 1
        local ok, err = pcall(fn)
        if ok then
            passed = passed + 1
        else
            io.stderr:write(string.format("  [FAIL] %s: %s\n", name, tostring(err)))
            error(err)
        end
    end

    it("PathSegment accepts strings and positive integers", function()
        assert(v.is(contracts.PathSegment, "foo"))
        assert(v.is(contracts.PathSegment, 1))
        assert(v.is(contracts.PathSegment, 42))

        assert(not v.is(contracts.PathSegment, 0))
        assert(not v.is(contracts.PathSegment, -1))
        assert(not v.is(contracts.PathSegment, true))
        assert(not v.is(contracts.PathSegment, {}))
    end)

    it("Mutation schema validates all valid mutation shapes", function()
        local m1 = { kind = "set", path = { "a", 1, "b" }, value = "hello" }
        local m2 = { kind = "remove", path = { "a" } }
        local m3 = { kind = "ensure_object", path = { "b" } }
        local m4 = { kind = "ensure_array", path = { "c" } }
        local m5 = { kind = "merge", path = { "d" }, value = { x = 1 }, deep = true }
        local m6 = { kind = "append_unique", path = { "e" }, value = { name = "lib" }, key = "name" }

        assert(v.is(contracts.Mutation, m1))
        assert(v.is(contracts.Mutation, m2))
        assert(v.is(contracts.Mutation, m3))
        assert(v.is(contracts.Mutation, m4))
        assert(v.is(contracts.Mutation, m5))
        assert(v.is(contracts.Mutation, m6))
    end)

    it("Mutation schema rejects invalid mutation kinds or invalid paths", function()
        local bad1 = { kind = "invalid_kind", path = { "a" } }
        local bad2 = { kind = "set", path = { 0 } } -- 0 is invalid index

        assert(not v.is(contracts.Mutation, bad1))
        assert(not v.is(contracts.Mutation, bad2))
    end)

    it("Conflict schema validates structured conflict objects", function()
        local c = {
            kind = "conflict",
            path = { "runtime", "plugin" },
            expected = "object",
            actual = "string",
            message = "Conflict at runtime.plugin: expected object, got string",
        }
        assert(v.is(contracts.Conflict, c))
    end)

    it("CommitResult and RenderResult schemas validate result shapes", function()
        local muts = { { kind = "set", path = { "a" }, value = 1 } }
        local cr = {
            changed = true,
            mutations = muts,
            text = '{"a": 1}',
            bytes_written = 8,
        }
        local rr = {
            changed = true,
            mutations = muts,
            text = '{"a": 1}',
        }
        assert(v.is(contracts.CommitResult, cr))
        assert(v.is(contracts.RenderResult, rr))
    end)

    return { total = total, passed = passed }
end

return { run = run }
