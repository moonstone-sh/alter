local contracts = require("contracts")

describe("LuaCATS Type Synchronization (src/alter/types.lua)", function()
    local function read_file(path)
        local f = io.open(path, "r")
        if not f then
            f = io.open("src/alter/types.lua", "r") or io.open("../src/alter/types.lua", "r") or io.open("host/src/alter/types.lua", "r")
        end
        if not f then
            error("Could not find types.lua file")
        end
        local content = f:read("*a")
        f:close()
        return content
    end

    local types_content = read_file("src/alter/types.lua")

    local function read_contracts()
        local f = io.open("contracts/all.lua", "r")
            or io.open("host/contracts/all.lua", "r")
        assert_not_nil(f, "Could not find canonical contracts/all.lua")
        local content = f:read("*a")
        f:close()
        return content
    end

    local contracts_content = read_contracts()

    it("defines alter.Path and PathSegment annotations", function()
        assert_true(contracts_content:find("@valua%-alias%s+alter%.PathSegment%s+PathSegment") ~= nil,
            "canonical Valua PathSegment alias directive missing")
        assert_true(contracts_content:find("@valua%-alias%s+alter%.Path%s+Path") ~= nil,
            "canonical Valua Path alias directive missing")
        assert_true(types_content:find("@alias%s+alter%.PathSegment%s+string|integer") ~= nil, "alter.PathSegment alias missing")
        assert_true(types_content:find("@alias%s+alter%.Path%s+alter%.PathSegment%[%]") ~= nil, "alter.Path alias missing")
    end)

    it("defines alter.MutationKind alias with all 8 operations", function()
        assert_true(contracts_content:find("@valua%-alias%s+alter%.MutationKind%s+MutationKind") ~= nil,
            "canonical Valua MutationKind alias directive missing")
        assert_true(types_content:find("@alias%s+alter%.MutationKind") ~= nil, "alter.MutationKind alias missing")
        local kinds = { "set", "remove", "ensure", "ensure_object", "ensure_array", "merge", "append", "append_unique" }
        for _, kind in ipairs(kinds) do
            assert_true(types_content:find('"' .. kind .. '"') ~= nil, "MutationKind missing '" .. kind .. "'")
        end
    end)

    it("defines alter.Mutation class with all schema fields", function()
        assert_true(contracts_content:find("@valua%-alias%s+alter%.Mutation%s+Mutation") ~= nil,
            "canonical Valua Mutation alias directive missing")
        assert_true(types_content:find("@class%s+alter%.Mutation") ~= nil, "alter.Mutation class missing")
        assert_true(types_content:find("@field%s+kind%s+alter%.MutationKind") ~= nil, "field kind missing")
        assert_true(types_content:find("@field%s+path%s+alter%.Path") ~= nil, "field path missing")
        assert_true(types_content:find("@field%s+value") ~= nil, "field value missing")
        assert_true(types_content:find("@field%s+deep") ~= nil, "field deep missing")
        assert_true(types_content:find("@field%s+key") ~= nil, "field key missing")
    end)

    it("defines alter.BackendCapabilities class matching contract", function()
        assert_true(contracts_content:find("@valua%-alias%s+alter%.BackendCapabilities%s+BackendCapabilities") ~= nil,
            "canonical Valua BackendCapabilities alias directive missing")
        assert_true(types_content:find("@class%s+alter%.BackendCapabilities") ~= nil, "alter.BackendCapabilities missing")
        assert_true(types_content:find("@field%s+comments%s+boolean") ~= nil, "field comments missing")
        assert_true(types_content:find("@field%s+ordering%s+boolean") ~= nil, "field ordering missing")
        assert_true(types_content:find("@field%s+formatting%s+boolean") ~= nil, "field formatting missing")
        assert_true(types_content:find("@field%s+duplicate_keys%s+boolean") ~= nil, "field duplicate_keys missing")
        assert_true(types_content:find("@field%s+minimal_edits%s+boolean") ~= nil, "field minimal_edits missing")
    end)

    it("defines alter.Conflict class matching contract", function()
        assert_true(contracts_content:find("@valua%-alias%s+alter%.Conflict%s+Conflict") ~= nil,
            "canonical Valua Conflict alias directive missing")
        assert_true(types_content:find("@class%s+alter%.Conflict") ~= nil, "alter.Conflict class missing")
        assert_true(types_content:find("@field%s+path%s+alter%.Path") ~= nil, "field path missing")
        assert_true(types_content:find("@field%s+expected%s+string") ~= nil, "field expected missing")
        assert_true(types_content:find("@field%s+actual%s+string") ~= nil, "field actual missing")
        assert_true(types_content:find("@field%s+message%s+string") ~= nil, "field message missing")
    end)

    it("defines alter.Error class matching contract", function()
        assert_true(contracts_content:find("@valua%-alias%s+alter%.Error%s+Error") ~= nil,
            "canonical Valua Error alias directive missing")
        assert_true(types_content:find("@class%s+alter%.Error") ~= nil, "alter.Error class missing")
        assert_true(types_content:find("@field%s+kind%s+string") ~= nil, "field kind missing")
        assert_true(types_content:find("@field%s+message%s+string") ~= nil, "field message missing")
    end)

    it("defines alter.CommitResult & RenderResult classes matching contracts", function()
        assert_true(contracts_content:find("@valua%-alias%s+alter%.CommitResult%s+CommitResult") ~= nil,
            "canonical Valua CommitResult alias directive missing")
        assert_true(contracts_content:find("@valua%-alias%s+alter%.RenderResult%s+RenderResult") ~= nil,
            "canonical Valua RenderResult alias directive missing")
        assert_true(types_content:find("@class%s+alter%.CommitResult") ~= nil, "alter.CommitResult missing")
        assert_true(types_content:find("@field%s+changed%s+boolean") ~= nil, "field changed missing")
        assert_true(types_content:find("@field%s+text%s+string") ~= nil, "field text missing")
        assert_true(types_content:find("@field%s+bytes_written%s+integer") ~= nil, "field bytes_written missing")

        assert_true(types_content:find("@class%s+alter%.RenderResult") ~= nil, "alter.RenderResult missing")
    end)

    it("defines alter.Document and alter.Cursor class annotations", function()
        assert_true(types_content:find("@class%s+alter%.Document") ~= nil, "alter.Document missing")
        assert_true(types_content:find("@class%s+alter%.Cursor") ~= nil, "alter.Cursor missing")
    end)

    it("defines the implemented backend protocol", function()
        assert_true(types_content:find("@class%s+alter%.BackendDocument") ~= nil, "alter.BackendDocument missing")
        for _, method in ipairs({ "resolve", "kind_at", "value_at", "apply", "render", "clone" }) do
            assert_true(types_content:find("@field%s+" .. method .. "%s+fun") ~= nil, "BackendDocument method missing: " .. method)
        end
        assert_true(types_content:find("@class%s+alter%.Backend") ~= nil, "alter.Backend missing")
        assert_true(types_content:find("@field%s+parse%s+fun%(text:%s+string") ~= nil, "Backend.parse signature missing")
    end)

    it("publishes all cursor mutation operations", function()
        for _, method in ipairs({ "set", "remove", "ensure", "ensure_object", "ensure_array", "merge", "append", "append_unique" }) do
            assert_true(types_content:find("@field%s+" .. method .. "%s+fun%(self:%s+alter%.Cursor") ~= nil, "Cursor method missing: " .. method)
        end
    end)

    it("publishes module construction functions and does not advertise removed API", function()
        assert_true(types_content:find("@class%s+alter%.Module") ~= nil, "alter.Module missing")
        for _, method in ipairs({ "parse", "create", "open" }) do
            assert_true(types_content:find("@field%s+" .. method .. "%s+fun") ~= nil, "Module method missing: " .. method)
        end
        assert_true(types_content:find("apply_mutations") == nil, "types.lua advertises the removed apply_mutations protocol")
        assert_true(types_content:find("serialize%s+fun") == nil, "types.lua advertises the removed serialize protocol")
    end)

    it("types public require entry points", function()
        local function entry_has_return(path, expected)
            local f = io.open(path, "r")
                or io.open("../" .. path, "r")
                or io.open("host/" .. path, "r")
            assert_not_nil(f, "Could not find " .. path)
            local content = f:read("*a")
            f:close()
            assert_true(content:find("@return%s+" .. expected) ~= nil, path .. " is missing its return type")
        end
        entry_has_return("src/alter.lua", "alter%.Module")
    end)

    it("Valua's LuaLS emitter resolves every canonical data contract", function()
        local plugin = require("valua.tooling.luals.plugin")
        local emitted = plugin.analyze_source(contracts_content, "contracts/all.lua")
        local declarations = {}
        for _, result in ipairs(emitted) do
            declarations[result.var_name] = result.luacats
        end
        for _, name in ipairs({
            "alter.PathSegment", "alter.Path", "alter.MutationKind", "alter.Mutation",
            "alter.BackendCapabilities", "alter.Conflict", "alter.Error",
            "alter.CommitResult", "alter.RenderResult", "alter.BackendDescriptor",
        }) do
            assert_not_nil(declarations[name], "Valua did not infer " .. name)
            assert_true(types_content:find(name:gsub("%.", "%%.")) ~= nil,
                "published LuaCATS is missing " .. name)
        end
    end)
end)
