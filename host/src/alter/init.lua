local Document = require("alter.document")
local backend_mod = require("alter.backend")
local errors = require("alter.errors")
local path_mod = require("alter.path")
local mutation_mod = require("alter.mutation")

---@type alter.Module
local alter = {
    _VERSION = "0.1.0",
    NULL = setmetatable({}, {
        __tostring = function() return "null" end,
    }),
    errors = errors,
    path = path_mod,
    mutation = mutation_mod,
}

---@param text string
---@param backend alter.Backend
---@param opts? alter.ParseOptions
---@return alter.Document|nil document
---@return alter.Error|nil err
function alter.parse(text, backend, opts)
    local valid, err = backend_mod.validate_backend(backend)
    if not valid then return nil, err end

    local backend_doc, parse_err = backend.parse(text, opts)
    if not backend_doc then
        return nil, parse_err or errors.error("parse_error", "Failed to parse document")
    end

    return Document.new({
        filepath = opts and opts.filepath,
        backend = backend,
        backend_doc = backend_doc,
        original_text = text or "",
        fs = opts and opts.fs,
    })
end

---@param backend alter.Backend
---@param opts? alter.ParseOptions
---@return alter.Document|nil document
---@return alter.Error|nil err
function alter.create(backend, opts)
    return alter.parse("", backend, opts)
end

---@param filepath string
---@param opts alter.OpenOptions
---@return alter.Document|nil document
---@return alter.Error|nil err
function alter.open(filepath, opts)
    opts = opts or {}
    local backend = opts.backend
    if not backend then
        return nil, errors.error("invalid_options", "alter.open requires a 'backend' option")
    end

    local text = ""
    local f = io.open(filepath, "rb")
    if f then
        text = f:read("*a")
        f:close()
    else
        if not opts.create then
            return nil, errors.error("file_not_found", "File not found: " .. tostring(filepath))
        end
        text = opts.default_text or ""
    end

    local doc_opts = {
        filepath = filepath,
        fs = opts.fs,
    }

    return alter.parse(text, backend, doc_opts)
end

return alter
