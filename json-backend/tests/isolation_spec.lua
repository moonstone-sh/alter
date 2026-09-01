describe("JSON Backend Runtime Isolation", function()
    it("require('alter_json') does not load Valua into package.loaded", function()
        for k in pairs(package.loaded) do
            if k:find("^valua") or k:find("^alter") or k:find("^alter_json") or k:find("^alter%-json") then
                package.loaded[k] = nil
            end
        end

        local alter_json = require("alter_json")
        assert_not_nil(alter_json)

        for k in pairs(package.loaded) do
            assert_false(k:find("^valua") ~= nil, "Runtime leak: require('alter_json') loaded valua module '" .. tostring(k) .. "'")
        end
    end)

    it("require('alter-json') does not load Valua into package.loaded", function()
        for k in pairs(package.loaded) do
            if k:find("^valua") or k:find("^alter") or k:find("^alter_json") or k:find("^alter%-json") then
                package.loaded[k] = nil
            end
        end

        local ok, alter_json = pcall(require, "alter-json")
        if ok and alter_json then
            for k in pairs(package.loaded) do
                assert_false(k:find("^valua") ~= nil, "Runtime leak: require('alter-json') loaded valua module '" .. tostring(k) .. "'")
            end
        end
    end)
end)
