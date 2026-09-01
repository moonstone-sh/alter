describe("Runtime Dependency Isolation", function()
    it("require('alter') does not load Valua or its submodules", function()
        -- Purge any valua or alter modules from package.loaded
        for k in pairs(package.loaded) do
            if k:find("^valua") or k:find("^alter") then
                package.loaded[k] = nil
            end
        end

        -- Load alter host runtime
        local alter = require("alter")
        assert_not_nil(alter)

        -- Verify that alter modules are loaded
        assert_not_nil(package.loaded["alter"])
        assert_not_nil(package.loaded["alter.document"])
        assert_not_nil(package.loaded["alter.cursor"])

        -- Strict assertion: No valua modules should be in package.loaded!
        for k in pairs(package.loaded) do
            assert_false(k:find("^valua") ~= nil, "Runtime leak: valua module '" .. tostring(k) .. "' was loaded by require('alter')")
        end
    end)

    it("loading core submodules directly does not load Valua", function()
        local submodules = {
            "alter.path",
            "alter.errors",
            "alter.mutation",
            "alter.backend",
            "alter.cursor",
            "alter.document",
        }

        for _, mod in ipairs(submodules) do
            for k in pairs(package.loaded) do
                if k:find("^valua") then
                    package.loaded[k] = nil
                end
            end

            local loaded_mod = require(mod)
            assert_not_nil(loaded_mod)

            for k in pairs(package.loaded) do
                assert_false(k:find("^valua") ~= nil, "Runtime leak: require('" .. mod .. "') loaded valua module '" .. tostring(k) .. "'")
            end
        end
    end)
end)
