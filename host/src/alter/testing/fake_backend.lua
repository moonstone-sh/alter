local errors = require("alter.errors")
local mutation_mod = require("alter.mutation")

local FakeDocument = {}
FakeDocument.__index = FakeDocument

local function deep_copy(v)
    if type(v) ~= "table" then return v end
    local res = {}
    for k, val in pairs(v) do
        res[k] = deep_copy(val)
    end
    return res
end

local function determine_kind(v)
    if v == nil then return "none" end
    local t = type(v)
    if t == "string" then return "string"
    elseif t == "number" then return "number"
    elseif t == "boolean" then return "boolean"
    elseif t == "table" then
        if v._is_array then return "array" end
        -- Check if sequence
        local is_arr = true
        local count = 0
        for k in pairs(v) do
            count = count + 1
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_arr = false
                break
            end
        end
        if count > 0 and is_arr then
            for i = 1, count do
                if v[i] == nil then
                    is_arr = false
                    break
                end
            end
        end
        if count == 0 then
            return v._is_array and "array" or "object"
        end
        return is_arr and "array" or "object"
    end
    return "unknown"
end

-- Simple built-in JSON parser for FakeBackend
local function parse_simple_json(text)
    if not text or text:match("^%s*$") then return {} end
    local pos = 1
    local len = #text

    local function skip_ws()
        while pos <= len do
            local c = text:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                pos = pos + 1
            else
                break
            end
        end
    end

    local parse_val

    local function parse_str()
        pos = pos + 1 -- skip opening "
        local buf = {}
        while pos <= len do
            local c = text:sub(pos, pos)
            if c == "\\" then
                local next_c = text:sub(pos + 1, pos + 1)
                table.insert(buf, next_c == '"' and '"' or next_c)
                pos = pos + 2
            elseif c == '"' then
                pos = pos + 1
                return table.concat(buf, "")
            else
                table.insert(buf, c)
                pos = pos + 1
            end
        end
        error("Unterminated string")
    end

    local function parse_num()
        local start = pos
        while pos <= len do
            local c = text:sub(pos, pos)
            if (c >= "0" and c <= "9") or c == "-" or c == "+" or c == "." or c == "e" or c == "E" then
                pos = pos + 1
            else
                break
            end
        end
        return tonumber(text:sub(start, pos - 1))
    end

    local function parse_arr()
        pos = pos + 1 -- skip [
        local arr = { _is_array = true }
        skip_ws()
        if pos <= len and text:sub(pos, pos) == "]" then
            pos = pos + 1
            return arr
        end
        while pos <= len do
            skip_ws()
            if text:sub(pos, pos) == "]" then pos = pos + 1; break end
            local v = parse_val()
            table.insert(arr, v)
            skip_ws()
            if text:sub(pos, pos) == "," then
                pos = pos + 1
            elseif text:sub(pos, pos) == "]" then
                pos = pos + 1
                break
            end
        end
        return arr
    end

    local function parse_obj()
        pos = pos + 1 -- skip {
        local obj = {}
        skip_ws()
        if pos <= len and text:sub(pos, pos) == "}" then
            pos = pos + 1
            return obj
        end
        while pos <= len do
            skip_ws()
            if text:sub(pos, pos) == "}" then pos = pos + 1; break end
            if text:sub(pos, pos) ~= '"' then error("Expected string key in object at pos " .. pos) end
            local k = parse_str()
            skip_ws()
            if text:sub(pos, pos) ~= ":" then error("Expected ':' after key at pos " .. pos) end
            pos = pos + 1
            skip_ws()
            local v = parse_val()
            obj[k] = v
            skip_ws()
            if text:sub(pos, pos) == "," then
                pos = pos + 1
            elseif text:sub(pos, pos) == "}" then
                pos = pos + 1
                break
            end
        end
        return obj
    end

    parse_val = function()
        skip_ws()
        if pos > len then return nil end
        local c = text:sub(pos, pos)
        if c == "{" then return parse_obj()
        elseif c == "[" then return parse_arr()
        elseif c == '"' then return parse_str()
        elseif (c >= "0" and c <= "9") or c == "-" then return parse_num()
        elseif text:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
        elseif text:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
        elseif text:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
        else
            error("Unexpected char: " .. c .. " at pos " .. pos)
        end
    end

    local ok, res = pcall(parse_val)
    if ok and type(res) == "table" then return res end
    return {}
end

function FakeDocument.new(data, raw_text)
    return setmetatable({
        _data = deep_copy(data or {}),
        _raw_text = raw_text,
    }, FakeDocument)
end

function FakeDocument:resolve(path)
    local cur = self._data
    for _, seg in ipairs(path or {}) do
        if type(cur) ~= "table" then return nil end
        cur = cur[seg]
    end
    return cur
end

function FakeDocument:kind_at(path)
    local val = self:resolve(path)
    return determine_kind(val)
end

function FakeDocument:value_at(path)
    local val = self:resolve(path)
    return deep_copy(val)
end

function FakeDocument:clone()
    return FakeDocument.new(self._data, self._raw_text)
end

local function simple_serialize(v)
    local k = determine_kind(v)
    if k == "string" then
        return string.format("%q", v)
    elseif k == "number" or k == "boolean" then
        return tostring(v)
    elseif k == "array" then
        local parts = {}
        for _, item in ipairs(v) do
            table.insert(parts, simple_serialize(item))
        end
        return "[" .. table.concat(parts, ", ") .. "]"
    elseif k == "object" then
        local parts = {}
        local sorted_keys = {}
        for key in pairs(v) do
            if key ~= "_is_array" then
                table.insert(sorted_keys, key)
            end
        end
        table.sort(sorted_keys)
        for _, key in ipairs(sorted_keys) do
            table.insert(parts, string.format("%s: %s", key, simple_serialize(v[key])))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif k == "none" then
        return "null"
    end
    return tostring(v)
end

function FakeDocument:render()
    return simple_serialize(self._data)
end

function FakeDocument:apply(mut)
    local path = mut.path or {}
    local kind = mut.kind

    if #path == 0 then
        if kind == "set" then
            self._data = deep_copy(mut.value)
            return true
        elseif kind == "ensure_object" then
            if determine_kind(self._data) ~= "object" and determine_kind(self._data) ~= "none" then
                return false, errors.conflict(path, "object", determine_kind(self._data))
            end
            if self._data == nil or type(self._data) ~= "table" then
                self._data = {}
            end
            return true
        elseif kind == "ensure_array" then
            if determine_kind(self._data) ~= "array" and determine_kind(self._data) ~= "none" then
                return false, errors.conflict(path, "array", determine_kind(self._data))
            end
            if self._data == nil or type(self._data) ~= "table" then
                self._data = { _is_array = true }
            end
            return true
        end
    end

    -- Navigate to parent
    local cur = self._data
    for i = 1, #path - 1 do
        local seg = path[i]
        local next_val = cur[seg]
        if next_val == nil then
            local next_seg = path[i + 1]
            local new_container = (type(next_seg) == "number") and { _is_array = true } or {}
            cur[seg] = new_container
            cur = new_container
        elseif type(next_val) == "table" then
            cur = next_val
        else
            return false, errors.conflict({ table.unpack(path, 1, i) }, "object", determine_kind(next_val))
        end
    end

    local last_seg = path[#path]

    if kind == "set" then
        if determine_kind(cur) ~= "object" and determine_kind(cur) ~= "array" then
            return false, errors.conflict(path, "object", determine_kind(cur))
        end
        cur[last_seg] = deep_copy(mut.value)
        return true
    elseif kind == "remove" then
        if type(cur) == "table" then
            if type(last_seg) == "number" and cur._is_array then
                table.remove(cur, last_seg)
            else
                cur[last_seg] = nil
            end
        end
        return true
    elseif kind == "ensure" then
        if cur[last_seg] == nil then
            cur[last_seg] = deep_copy(mut.value)
        end
        return true
    elseif kind == "ensure_object" then
        local existing = cur[last_seg]
        if existing == nil then
            cur[last_seg] = {}
            return true
        elseif determine_kind(existing) == "object" then
            return true
        else
            return false, errors.conflict(path, "object", determine_kind(existing))
        end
    elseif kind == "ensure_array" then
        local existing = cur[last_seg]
        if existing == nil then
            cur[last_seg] = { _is_array = true }
            return true
        elseif determine_kind(existing) == "array" then
            return true
        else
            return false, errors.conflict(path, "array", determine_kind(existing))
        end
    elseif kind == "merge" then
        local existing = cur[last_seg]
        if existing == nil then
            existing = {}
            cur[last_seg] = existing
        elseif determine_kind(existing) ~= "object" then
            return false, errors.conflict(path, "object", determine_kind(existing))
        end
        if type(mut.value) == "table" then
            for k, v in pairs(mut.value) do
                if mut.deep and type(v) == "table" and type(existing[k]) == "table" then
                    for sub_k, sub_v in pairs(v) do
                        existing[k][sub_k] = deep_copy(sub_v)
                    end
                else
                    existing[k] = deep_copy(v)
                end
            end
        end
        return true
    elseif kind == "append" then
        local existing = cur[last_seg]
        if existing == nil then
            existing = { _is_array = true }
            cur[last_seg] = existing
        elseif determine_kind(existing) ~= "array" then
            return false, errors.conflict(path, "array", determine_kind(existing))
        end
        table.insert(existing, deep_copy(mut.value))
        return true
    elseif kind == "append_unique" then
        local existing = cur[last_seg]
        if existing == nil then
            existing = { _is_array = true }
            cur[last_seg] = existing
        elseif determine_kind(existing) ~= "array" then
            return false, errors.conflict(path, "array", determine_kind(existing))
        end
        local val = mut.value
        local found = false
        for _, elem in ipairs(existing) do
            if mut.key and type(elem) == "table" and type(val) == "table" then
                if elem[mut.key] == val[mut.key] and val[mut.key] ~= nil then
                    found = true
                    break
                end
            else
                if mutation_mod.deep_equal(elem, val) then
                    found = true
                    break
                end
            end
        end
        if not found then
            table.insert(existing, deep_copy(val))
        end
        return true
    end

    return false, errors.error("unsupported_mutation", "Unsupported mutation kind: " .. tostring(kind), path)
end

local FakeBackend = {
    name = "fake",
    capabilities = {
        comments = false,
        ordering = true,
        formatting = false,
        duplicate_keys = false,
        minimal_edits = false,
    },
}

function FakeBackend.parse(text, opts)
    local data = (opts and opts.initial_data) or parse_simple_json(text or "")
    return FakeDocument.new(data, text), nil
end

return FakeBackend
