local Cursor = require("alter.cursor")
local path_mod = require("alter.path")
local mutation_mod = require("alter.mutation")
local errors = require("alter.errors")

local Document = {}
Document.__index = Document

function Document.new(opts)
    local self = setmetatable({}, Document)
    self._filepath = opts.filepath
    self._backend = opts.backend
    self._backend_doc = opts.backend_doc
    self._original_text = opts.original_text or ""
    self._mutations = {}
    self._fs = opts.fs
    return self
end

function Document:at(...)
    local target_path = path_mod.normalize(...)
    return Cursor.new(self, target_path)
end

function Document:kind_at(path)
    local p = path_mod.normalize(path)
    return self._backend_doc:kind_at(p) or "none"
end

function Document:value_at(path)
    local p = path_mod.normalize(path)
    return self._backend_doc:value_at(p)
end

function Document:stage(mutation)
    table.insert(self._mutations, mutation)
    return self
end

function Document:mutations()
    local res = {}
    for i, mut in ipairs(self._mutations) do
        res[i] = mutation_mod.clone(mut)
    end
    return res
end

function Document:clear_mutations()
    self._mutations = {}
    return self
end

function Document:rollback()
    self._mutations = {}
    return self
end

function Document:changed()
    if #self._mutations == 0 then
        return false
    end
    local _, res = self:render()
    return res and res.changed or false
end

function Document:render()
    if #self._mutations == 0 then
        local render_result = {
            changed = false,
            mutations = {},
            text = self._original_text,
        }
        return self._original_text, render_result, self._backend_doc
    end

    local working_doc = self._backend_doc:clone()
    for _, mut in ipairs(self._mutations) do
        local ok, err = working_doc:apply(mut)
        if not ok then
            return nil, err
        end
    end

    local rendered_text = working_doc:render()
    local is_changed = (rendered_text ~= self._original_text)

    local mutations_copy = self:mutations()
    local render_result = {
        changed = is_changed,
        mutations = mutations_copy,
        text = rendered_text,
    }

    return rendered_text, render_result, working_doc
end

function Document:commit()
    local rendered_text, render_result, working_doc = self:render()
    if not rendered_text then
        return nil, render_result -- render_result contains error
    end

    local bytes_written = 0
    if render_result.changed and self._filepath then
        local fs = self._fs
        if fs and fs.write_file_atomic then
            local ok, err = fs.write_file_atomic(self._filepath, rendered_text)
            if not ok then
                return nil, errors.error("io_error", "Failed to write file: " .. tostring(err), nil, err)
            end
        else
            -- Default atomic write
            local tmp_path = self._filepath .. ".tmp." .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
            local f, err = io.open(tmp_path, "wb")
            if not f then
                return nil, errors.error("io_error", "Failed to open tmp file: " .. tostring(err), nil, err)
            end
            f:write(rendered_text)
            f:close()
            local ren_ok, ren_err = os.rename(tmp_path, self._filepath)
            if not ren_ok then
                os.remove(tmp_path)
                return nil, errors.error("io_error", "Failed to commit atomic rename: " .. tostring(ren_err), nil, ren_err)
            end
        end
        bytes_written = #rendered_text
    end

    -- Update active document state to committed state
    self._original_text = rendered_text
    self._backend_doc = working_doc
    self._mutations = {}

    local commit_result = {
        changed = render_result.changed,
        mutations = render_result.mutations,
        text = rendered_text,
        bytes_written = bytes_written,
    }

    return commit_result
end

return Document
