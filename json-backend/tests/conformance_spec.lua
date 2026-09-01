local alter_json = require("alter_json")
local conformance = require("alter.testing.backend_conformance")

describe("JSON Backend Conformance Suite", function()
    it("satisfies the alter backend conformance test matrix", function()
        local results = conformance.run({
            backend = alter_json,
            empty_text = "{}",
            sample_text = '{\n  "key": "value",\n  "count": 10\n}',
            scalar_conflict_text = '{\n  "runtime": "string_value"\n}',
        })

        assert_equal(results.failures and #results.failures or 0, 0, "Conformance suite had failures")
        assert_true(results.passed > 0, "Conformance suite passed tests")
    end)
end)
