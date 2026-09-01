local JsonDocument = require("alter_json.document")
local parser = require("alter_json.parser")

---@type alter.Backend
local backend = {
    name = "json",
    capabilities = {
        comments = false,
        ordering = true,
        formatting = true,
        duplicate_keys = false,
        minimal_edits = true,
    },
}

---@param text string
---@param opts? table
---@return alter.BackendDocument|nil document
---@return alter.Error|nil err
function backend.parse(text, opts)
    local ast, err = parser.parse(text, opts)
    if not ast then
        return nil, err
    end
    return JsonDocument.new(ast, opts)
end

return backend
