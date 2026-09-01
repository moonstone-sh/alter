local alter_toml = require("alter_toml")
local conformance = require("alter.testing.backend_conformance")

describe("TOML Backend Conformance Suite", function()
    it("satisfies the alter backend conformance test matrix", function()
        local results = conformance.run({
            backend = alter_toml,
            empty_text = "",
            sample_text = "[workspace]\nname = \"sample\"\n",
            remove_sample_text = "a = 1\nb = 2\n",
            scalar_conflict_text = "runtime = \"string_value\"\n",
        })

        assert_equal(results.failures and #results.failures or 0, 0, "Conformance suite had failures")
        assert_true(results.passed > 0, "Conformance suite passed tests")
    end)
end)
