describe("TOML Backend Runtime Isolation", function()
    it("require('alter_toml') does not load Valua into package.loaded", function()
        for k in pairs(package.loaded) do
            if k:find("^valua") or k:find("^alter") or k:find("^alter_toml") or k:find("^alter%-toml") then
                package.loaded[k] = nil
            end
        end

        local alter_toml = require("alter_toml")
        assert_not_nil(alter_toml)

        for k in pairs(package.loaded) do
            assert_false(k:find("^valua") ~= nil, "Runtime leak: require('alter_toml') loaded valua module '" .. tostring(k) .. "'")
        end
    end)

    it("require('alter-toml') does not load Valua into package.loaded", function()
        for k in pairs(package.loaded) do
            if k:find("^valua") or k:find("^alter") or k:find("^alter_toml") or k:find("^alter%-toml") then
                package.loaded[k] = nil
            end
        end

        local ok, alter_toml = pcall(require, "alter-toml")
        if ok and alter_toml then
            for k in pairs(package.loaded) do
                assert_false(k:find("^valua") ~= nil, "Runtime leak: require('alter-toml') loaded valua module '" .. tostring(k) .. "'")
            end
        end
    end)
end)
