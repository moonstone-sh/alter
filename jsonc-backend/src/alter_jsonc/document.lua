local JsonDocument = require("alter_json.document")

---@class alter.jsonc.Document: alter.BackendDocument
local JsoncDocument = {}
JsoncDocument.__index = JsoncDocument
setmetatable(JsoncDocument, { __index = JsonDocument })

function JsoncDocument.new(ast, comments)
    local self = setmetatable(JsonDocument.new(ast), JsoncDocument)
    self._comments = comments or {}
    return self
end

function JsoncDocument:clone()
    local clone = JsonDocument.clone(self)
    local comments = {}
    for i, comment in ipairs(self._comments) do comments[i] = comment end
    return JsoncDocument.new(clone._ast, comments)
end

function JsoncDocument:render()
    local text = JsonDocument.render(self)
    if #self._comments == 0 then return text end
    -- Comments are retained verbatim. They are emitted ahead of the rewritten
    -- document because v0.1 JSONC has structural, not token-range, edits.
    return table.concat(self._comments, "\n") .. "\n" .. text
end

return JsoncDocument
