local parser = require("alter_json.parser")
local serializer = require("alter_json.serializer")
local mutator = require("alter_json.mutator")

---@class alter.json.Document: alter.BackendDocument
local JsonDocument = {}
JsonDocument.__index = JsonDocument

function JsonDocument.new(ast, raw_text)
    return setmetatable({
        _ast = ast,
        _raw_text = raw_text,
    }, JsonDocument)
end

function JsonDocument:resolve(path)
    local node = mutator.resolve_node(self._ast, path)
    return node
end

function JsonDocument:kind_at(path)
    local node = self:resolve(path)
    if not node then return "none" end
    return node.kind
end

function JsonDocument:value_at(path)
    local node = self:resolve(path)
    if not node then return nil end
    return mutator.ast_to_lua_value(node)
end

function JsonDocument:apply(mutation)
    return mutator.apply(self._ast, mutation)
end

function JsonDocument:render()
    return serializer.serialize(self._ast)
end

function JsonDocument:clone()
    return JsonDocument.new(mutator.clone_ast(self._ast), self._raw_text)
end

return JsonDocument
