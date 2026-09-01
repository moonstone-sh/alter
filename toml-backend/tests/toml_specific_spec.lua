local alter = require("alter")
local TomlBackend = require("alter_toml")

describe("TOML Specific Features & Comment Preservation", function()
    it("preserves comments and section headers when mutating keys", function()
        local input = '# Project Manifest\n\n[package]\nname = "my-app" # The app name\nversion = "0.1.0"\n'
        local doc = alter.parse(input, TomlBackend)
        doc:at("package", "version"):set("0.2.0")
        local text, res = doc:render()
        assert_true(res.changed)
        assert_match(text, "# Project Manifest")
        assert_match(text, "# The app name")
        assert_match(text, 'version = "0.2.0"')
    end)

    it("supports adding new sections with proper formatting", function()
        local input = '[package]\nname = "pkg"\n'
        local doc = alter.parse(input, TomlBackend)
        doc:at("dependencies"):ensure_object()
           :at("valua"):set("^0.2.2")
        
        local text, res = doc:render()
        assert_true(res.changed)
        assert_match(text, "%[dependencies%]")
        assert_match(text, 'valua = "%^0.2.2"')
    end)

    it("supports array of table sections and idempotence", function()
        local input = '[[registries]]\nname = "local"\nurl = "file:///tmp"\n'
        local doc = alter.parse(input, TomlBackend)
        local c = doc:at("registries")
        assert_true(c:exists())

        local commit1 = doc:commit()
        assert_false(commit1.changed)
    end)
end)
