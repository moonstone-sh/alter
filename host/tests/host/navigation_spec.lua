local alter = require("alter")
local FakeBackend = require("alter.testing.fake_backend")

describe("Navigation Invariance & Non-Mutation Proofs", function()
    local sample = '{"package": {"name": "alter", "version": "0.1.0"}, "dependencies": ["valua"]}'

    it("deep chained navigation over non-existent paths leaves document pristine", function()
        local doc = alter.parse(sample, FakeBackend)
        local initial_text = doc:render()

        local c = doc:at("a"):at("b"):at("c"):at("d"):at("e"):at("f")
        assert_false(c:exists())
        assert_equal(c:kind(), "none")
        assert_nil(c:get())

        assert_equal(#doc:mutations(), 0)
        assert_false(doc:changed())
        local rendered_text = doc:render()
        assert_equal(rendered_text, initial_text)
    end)

    it("typo keys on existing objects never mutate or create shadow keys", function()
        local doc = alter.parse(sample, FakeBackend)

        local typo1 = doc:at("packge")
        local typo2 = doc:at("package", "verison")
        local typo3 = doc:at("package", "Name")

        assert_false(typo1:exists())
        assert_false(typo2:exists())
        assert_false(typo3:exists())
        assert_nil(typo1:get())
        assert_nil(typo2:get())
        assert_nil(typo3:get())

        assert_equal(#doc:mutations(), 0)
        assert_false(doc:changed())
    end)

    it("out-of-bounds array navigation never mutates", function()
        local doc = alter.parse(sample, FakeBackend)

        local item1 = doc:at("dependencies", 1)
        assert_true(item1:exists())
        assert_equal(item1:get(), "valua")

        local item_oob = doc:at("dependencies", 999)
        assert_false(item_oob:exists())
        assert_nil(item_oob:get())

        local item_nested = doc:at("dependencies", 999, "field", "subfield")
        assert_false(item_nested:exists())
        assert_nil(item_nested:get())

        assert_equal(#doc:mutations(), 0)
        assert_false(doc:changed())
    end)

    it("multiple independent cursors do not interfere or leak state", function()
        local doc = alter.parse(sample, FakeBackend)

        local c_pkg = doc:at("package")
        local c_name = c_pkg:at("name")
        local c_ver = c_pkg:at("version")
        local c_missing = c_pkg:at("missing")

        assert_equal(c_name:get(), "alter")
        assert_equal(c_ver:get(), "0.1.0")
        assert_nil(c_missing:get())

        assert_equal(#doc:mutations(), 0)
        assert_false(doc:changed())
    end)

    it("path normalization and clone purity in cursors", function()
        local doc = alter.parse(sample, FakeBackend)
        local c = doc:at({ "package", "name" })
        local p1 = c:path()
        local p2 = c:path()
        assert_equal(#p1, 2)
        assert_equal(#p2, 2)
        
        -- Modifying returned path table does not affect cursor internal path
        table.insert(p1, "mutated")
        assert_equal(#c:path(), 2)
    end)
end)
