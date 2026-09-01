local alter = require("alter")
local FakeBackend = require("alter.testing.fake_backend")
local contracts = require("contracts")
local v = require("valua")

describe("Host Conflict & Structured Error Detection", function()
    local function assert_is_conflict(err, expected_type, actual_type)
        assert_not_nil(err, "Expected error to be returned")
        assert_equal(err.kind, "conflict", "Expected error.kind == 'conflict'")
        if expected_type then
            assert_equal(err.expected, expected_type)
        end
        if actual_type then
            assert_equal(err.actual, actual_type)
        end
        local parsed = v.safe_parse(contracts.Conflict, err)
        assert_true(parsed.success, "Error must satisfy contracts.Conflict schema")
    end

    it("ensure_object on string scalar returns Conflict", function()
        local doc = alter.parse('{"version": "1.0.0"}', FakeBackend)
        doc:at("version"):ensure_object()

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "object", "string")
    end)

    it("ensure_object on number scalar returns Conflict", function()
        local doc = alter.parse('{"count": 42}', FakeBackend)
        doc:at("count"):ensure_object()

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "object", "number")
    end)

    it("ensure_object on boolean scalar returns Conflict", function()
        local doc = alter.parse('{"active": true}', FakeBackend)
        doc:at("active"):ensure_object()

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "object", "boolean")
    end)

    it("ensure_object on array returns Conflict", function()
        local doc = alter.parse('{"items": ["a", "b"]}', FakeBackend)
        doc:at("items"):ensure_object()

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "object", "array")
    end)

    it("ensure_array on string scalar returns Conflict", function()
        local doc = alter.parse('{"name": "alter"}', FakeBackend)
        doc:at("name"):ensure_array()

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "array", "string")
    end)

    it("ensure_array on object returns Conflict", function()
        local doc = alter.parse('{"settings": {"theme": "dark"}}', FakeBackend)
        doc:at("settings"):ensure_array()

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "array", "object")
    end)

    it("append on scalar returns Conflict", function()
        local doc = alter.parse('{"tag": "v1"}', FakeBackend)
        doc:at("tag"):append("v2")

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "array", "string")
    end)

    it("append on object returns Conflict", function()
        local doc = alter.parse('{"meta": {"k": "v"}}', FakeBackend)
        doc:at("meta"):append("new_val")

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "array", "object")
    end)

    it("append_unique on non-array returns Conflict", function()
        local doc = alter.parse('{"config": "scalar"}', FakeBackend)
        doc:at("config"):append_unique("val")

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "array", "string")
    end)

    it("merge on scalar returns Conflict", function()
        local doc = alter.parse('{"val": 123}', FakeBackend)
        doc:at("val"):merge({ a = 1 })

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "object", "number")
    end)

    it("deep traversal through scalar without intermediate object returns Conflict", function()
        local doc = alter.parse('{"leaf": "cannot_be_parent"}', FakeBackend)
        doc:at("leaf", "child", "grandchild"):set(100)

        local text, err = doc:render()
        assert_nil(text)
        assert_is_conflict(err, "object", "string")
    end)
end)
