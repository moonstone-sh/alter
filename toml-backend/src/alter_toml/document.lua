local parser = require("alter_toml.parser")
local serializer = require("alter_toml.serializer")
local mutator = require("alter_toml.mutator")

---@class alter.toml.Document: alter.BackendDocument
local TomlDocument = {}
TomlDocument.__index = TomlDocument

function TomlDocument.new(ast, raw_text)
    return setmetatable({
        _ast = ast,
        _raw_text = raw_text,
    }, TomlDocument)
end

function TomlDocument:resolve(path)
    return mutator.resolve_node(self._ast, path)
end

function TomlDocument:kind_at(path)
    local node = self:resolve(path)
    if not node then return "none" end
    return node.kind
end

function TomlDocument:value_at(path)
    local node = self:resolve(path)
    if not node then return nil end
    return mutator.toml_val_to_lua(node)
end

function TomlDocument:apply(mutation)
    return mutator.apply(self._ast, mutation)
end

function TomlDocument:render()
    return serializer.serialize(self._ast)
end

function TomlDocument:clone()
    return TomlDocument.new(mutator.clone_ast(self._ast), self._raw_text)
end

return TomlDocument
