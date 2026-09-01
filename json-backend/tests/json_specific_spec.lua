local alter = require("alter")
local alter_json = require("alter_json")

describe("JSON Specific Features & Formatting Preservation", function()
    it("preserves 2-space indentation when updating keys", function()
        local input = '{\n  "name": "alter",\n  "version": 1\n}'
        local doc = alter.parse(input, alter_json)
        doc:at("version"):set(2)

        local output = doc:render()
        assert_match(output, '  "name": "alter"')
        assert_match(output, '  "version": 2')
    end)

    it("preserves 4-space indentation when adding new keys", function()
        local input = '{\n    "name": "alter",\n    "version": 1\n}'
        local doc = alter.parse(input, alter_json)
        doc:at("author"):set("moonstone")

        local output = doc:render()
        assert_match(output, '    "name": "alter"')
        assert_match(output, '    "author": "moonstone"')
    end)

    it("preserves key ordering of existing keys", function()
        local input = '{\n  "z_last": 1,\n  "a_first": 2,\n  "m_middle": 3\n}'
        local doc = alter.parse(input, alter_json)
        doc:at("a_first"):set(20)

        local output = doc:render()
        local pos_z = output:find('"z_last"')
        local pos_a = output:find('"a_first"')
        local pos_m = output:find('"m_middle"')

        assert_true(pos_z < pos_a, "z_last should precede a_first")
        assert_true(pos_a < pos_m, "a_first should precede m_middle")
    end)

    it("handles string escapes correctly", function()
        local input = '{\n  "escaped": "Line 1\\nLine 2\\tTabbed \\"quoted\\""\n}'
        local doc = alter.parse(input, alter_json)
        local val = doc:at("escaped"):get()
        assert_equal(val, 'Line 1\nLine 2\tTabbed "quoted"')

        doc:at("escaped"):set('New\nLine and "Quotes"')
        local output = doc:render()
        assert_match(output, 'New\\nLine and \\"Quotes\\"')
    end)

    it("handles numbers (integers, negative, floats)", function()
        local input = '{\n  "int": 42,\n  "neg": -100,\n  "float": 3.14159\n}'
        local doc = alter.parse(input, alter_json)
        assert_equal(doc:at("int"):get(), 42)
        assert_equal(doc:at("neg"):get(), -100)
        assert_true(math.abs(doc:at("float"):get() - 3.14159) < 0.0001)

        doc:at("int"):set(999)
        local output = doc:render()
        assert_match(output, '999')
    end)

    it("handles booleans and null values", function()
        local input = '{\n  "is_active": true,\n  "is_disabled": false,\n  "optional": null\n}'
        local doc = alter.parse(input, alter_json)
        assert_equal(doc:at("is_active"):get(), true)
        assert_equal(doc:at("is_disabled"):get(), false)
        assert_equal(tostring(doc:at("optional"):get()), "null")

        doc:at("is_active"):set(false)
        doc:at("optional"):set("now_defined")
        local output = doc:render()
        assert_match(output, '"is_active": false')
        assert_match(output, '"optional": "now_defined"')
    end)

    it("handles nested object creation and mutation", function()
        local doc = alter.parse('{}', alter_json)
        doc:at("server"):ensure_object()
        doc:at("server", "host"):set("127.0.0.1")
        doc:at("server", "port"):set(8080)

        local output = doc:render()
        assert_match(output, '"server"')
        assert_match(output, '"host": "127.0.0.1"')
        assert_match(output, '"port": 8080')

        local doc2 = alter.parse(output, alter_json)
        assert_equal(doc2:at("server", "host"):get(), "127.0.0.1")
        assert_equal(doc2:at("server", "port"):get(), 8080)
    end)

    it("handles array append, append_unique and remove operations", function()
        local input = '{\n  "tags": ["lua", "config"]\n}'
        local doc = alter.parse(input, alter_json)
        doc:at("tags"):append("alter"):append_unique("lua"):append_unique("json")

        local output = doc:render()
        local doc2 = alter.parse(output, alter_json)
        local tags = doc2:at("tags"):get()
        assert_equal(#tags, 4)
        assert_equal(tags[1], "lua")
        assert_equal(tags[2], "config")
        assert_equal(tags[3], "alter")
        assert_equal(tags[4], "json")

        doc2:at("tags", 2):remove()
        local output2 = doc2:render()
        local doc3 = alter.parse(output2, alter_json)
        local tags3 = doc3:at("tags"):get()
        assert_equal(#tags3, 3)
        assert_equal(tags3[1], "lua")
        assert_equal(tags3[2], "alter")
        assert_equal(tags3[3], "json")
    end)
end)
