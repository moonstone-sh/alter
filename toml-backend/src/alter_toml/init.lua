local parser = require("alter_toml.parser")
local TomlDocument = require("alter_toml.document")
local errors = require("alter.errors")

---@type alter.Backend
local TomlBackend = {
    name = "toml",
    capabilities = {
        comments = true,
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
function TomlBackend.parse(text, opts)
    local ok, ast_or_err = pcall(parser.parse, text or "")
    if not ok then
        return nil, errors.error("parse_error", "Failed to parse TOML: " .. tostring(ast_or_err))
    end
    return TomlDocument.new(ast_or_err, text), nil
end

return TomlBackend
