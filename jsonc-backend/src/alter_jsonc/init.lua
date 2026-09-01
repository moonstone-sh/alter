local parser = require("alter_jsonc.parser")
local JsoncDocument = require("alter_jsonc.document")

---@type alter.Backend
local backend = {
    name = "jsonc",
    capabilities = {
        comments = true,
        ordering = true,
        formatting = true,
        duplicate_keys = false,
        minimal_edits = false,
    },
}

---@param text string
---@param opts? table
---@return alter.BackendDocument|nil document
---@return alter.Error|nil err
function backend.parse(text, opts)
    local ast, comments_or_err = parser.parse(text or "", opts)
    if not ast then
        return nil, comments_or_err
    end
    return JsoncDocument.new(ast, comments_or_err), nil
end

return backend
