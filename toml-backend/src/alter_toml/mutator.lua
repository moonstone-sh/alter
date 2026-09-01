local alter = require("alter")
local errors = require("alter.errors")
local mutation_mod = require("alter.mutation")
local parser = require("alter_toml.parser")
local serializer = require("alter_toml.serializer")

local mutator = {}

local function lua_to_toml_val(val)
    if val == nil then return { kind = "string", value = "" } end
    local t = type(val)
    if t == "string" then
        return { kind = "string", value = val }
    elseif t == "number" then
        return { kind = "number", value = val }
    elseif t == "boolean" then
        return { kind = "boolean", value = val }
    elseif t == "table" then
        -- Array
        local is_arr = true
        local count = 0
        for k in pairs(val) do
            count = count + 1
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_arr = false
                break
            end
        end
        if count > 0 and is_arr then
            local elements = {}
            for i = 1, count do
                table.insert(elements, lua_to_toml_val(val[i]))
            end
            return { kind = "array", elements = elements }
        elseif count == 0 and val._is_array then
            return { kind = "array", elements = {} }
        else
            local entries = {}
            for k, v in pairs(val) do
                if k ~= "_is_array" then
                    table.insert(entries, {
                        key = tostring(k),
                        value = lua_to_toml_val(v),
                    })
                end
            end
            return { kind = "object", entries = entries, is_inline = true }
        end
    end
    return { kind = "string", value = tostring(val) }
end

local function toml_val_to_lua(node)
    if not node then return nil end
    if node.kind == "string" or node.kind == "number" or node.kind == "boolean" then
        return node.value
    elseif node.kind == "array" then
        local res = {}
        for i, el in ipairs(node.elements or {}) do
            res[i] = toml_val_to_lua(el)
        end
        return res
    elseif node.kind == "object" then
        local res = {}
        for _, ent in ipairs(node.entries or {}) do
            res[ent.key] = toml_val_to_lua(ent.value)
        end
        return res
    end
    return node.value
end

local function clone_val_node(node)
    if type(node) ~= "table" then return node end
    local c = {
        kind = node.kind,
        value = node.value,
        raw = node.raw,
        is_inline = node.is_inline,
    }
    if node.elements then
        c.elements = {}
        for i, el in ipairs(node.elements) do
            c.elements[i] = clone_val_node(el)
        end
    end
    if node.entries then
        c.entries = {}
        for i, ent in ipairs(node.entries) do
            c.entries[i] = {
                key = ent.key,
                value = clone_val_node(ent.value),
            }
        end
    end
    return c
end

local function clone_ast(ast)
    local c = {
        kind = "toml_doc",
        sections = {},
    }
    for _, sec in ipairs(ast.sections) do
        local sec_c = {
            header = sec.header,
            is_array_table = sec.is_array_table,
            raw_header = sec.raw_header,
            lines = {},
            entries = {},
        }
        for _, line in ipairs(sec.lines) do
            if line.kind == "entry" then
                local ent_c = {
                    kind = "entry",
                    key = line.key,
                    value = clone_val_node(line.value),
                    comment = line.comment,
                    raw_line = line.raw_line,
                }
                table.insert(sec_c.lines, ent_c)
                table.insert(sec_c.entries, ent_c)
            else
                table.insert(sec_c.lines, { kind = line.kind, text = line.text })
            end
        end
        table.insert(c.sections, sec_c)
    end
    return c
end

mutator.clone_ast = clone_ast
mutator.toml_val_to_lua = toml_val_to_lua
mutator.lua_to_toml_val = lua_to_toml_val

local function find_section(ast, header_name)
    for _, sec in ipairs(ast.sections) do
        if sec.header == header_name then
            return sec
        end
    end
    return nil
end

local function ensure_section(ast, header_name, is_array_table)
    local sec = find_section(ast, header_name)
    if sec then return sec end

    local header_text = is_array_table and string.format("[[%s]]", header_name) or string.format("[%s]", header_name)
    sec = {
        header = header_name,
        is_array_table = is_array_table or false,
        raw_header = header_text,
        lines = {
            { kind = "raw", text = "" }, -- blank line before section
            { kind = "header", text = header_text },
        },
        entries = {},
    }
    table.insert(ast.sections, sec)
    return sec
end

function mutator.resolve_node(ast, path)
    if not path or #path == 0 then
        return { kind = "object", is_root = true }
    end

    local first_seg = path[1]
    if type(first_seg) ~= "string" then return nil end

    -- Check if path matches a full section header e.g. path = {"a", "b"} -> header "a.b"
    local full_header = table.concat(path, ".")
    local sec = find_section(ast, full_header)
    if sec then
        return { kind = "object", section = sec }
    end

    -- If 1 segment, check root section entry or section
    if #path == 1 then
        local sec1 = find_section(ast, first_seg)
        if sec1 then return { kind = "object", section = sec1 } end
        local root_sec = ast.sections[1]
        for _, ent in ipairs(root_sec.entries) do
            if ent.key == first_seg then
                return ent.value
            end
        end
        return nil
    end

    -- Multi segment: e.g. {"workspace", "name"}
    -- Check section "workspace" for entry "name"
    local parent_header = table.concat(path, ".", 1, #path - 1)
    local target_key = path[#path]

    local target_sec = find_section(ast, parent_header)
    if target_sec then
        if type(target_key) == "string" then
            for _, ent in ipairs(target_sec.entries) do
                if ent.key == target_key then
                    return ent.value
                end
            end
        elseif type(target_key) == "number" then
            -- maybe array section or array entry
        end
    end

    -- Also check if path prefix is entry in root section
    local root_sec = ast.sections[1]
    for _, ent in ipairs(root_sec.entries) do
        if ent.key == first_seg then
            local cur = ent.value
            for i = 2, #path do
                local seg = path[i]
                if type(seg) == "string" and cur.kind == "object" then
                    local found = nil
                    for _, sub_ent in ipairs(cur.entries or {}) do
                        if sub_ent.key == seg then found = sub_ent.value; break end
                    end
                    cur = found
                elseif type(seg) == "number" and cur.kind == "array" then
                    cur = cur.elements and cur.elements[seg]
                else
                    return nil
                end
                if not cur then break end
            end
            return cur
        end
    end

    return nil
end

function mutator.apply(ast, mut)
    local path = mut.path or {}
    local kind = mut.kind

    if #path == 0 then
        if kind == "ensure_object" then return true end
        return false, errors.error("invalid_mutation", "Cannot apply root mutation " .. kind)
    end

    local last_seg = path[#path]

    if kind == "set" then
        if #path == 1 and type(last_seg) == "string" then
            local root_sec = ast.sections[1]
            local val_node = lua_to_toml_val(mut.value)
            local updated = false
            for _, ent in ipairs(root_sec.entries) do
                if ent.key == last_seg then
                    ent.value = val_node
                    updated = true
                    break
                end
            end
            if not updated then
                local ent = {
                    kind = "entry",
                    key = last_seg,
                    value = val_node,
                }
                table.insert(root_sec.lines, ent)
                table.insert(root_sec.entries, ent)
            end
            return true
        else
            local parent_header = table.concat(path, ".", 1, #path - 1)
            local sec = ensure_section(ast, parent_header)
            local val_node = lua_to_toml_val(mut.value)
            local updated = false
            for _, ent in ipairs(sec.entries) do
                if ent.key == last_seg then
                    ent.value = val_node
                    updated = true
                    break
                end
            end
            if not updated then
                local ent = {
                    kind = "entry",
                    key = tostring(last_seg),
                    value = val_node,
                }
                table.insert(sec.lines, ent)
                table.insert(sec.entries, ent)
            end
            return true
        end
    elseif kind == "remove" then
        if #path == 1 then
            local root_sec = ast.sections[1]
            for idx, ent in ipairs(root_sec.entries) do
                if ent.key == last_seg then
                    table.remove(root_sec.entries, idx)
                    break
                end
            end
            for idx, line in ipairs(root_sec.lines) do
                if line.kind == "entry" and line.key == last_seg then
                    table.remove(root_sec.lines, idx)
                    break
                end
            end
            -- Also check if it was a section [last_seg]
            for idx, sec in ipairs(ast.sections) do
                if sec.header == last_seg then
                    table.remove(ast.sections, idx)
                    break
                end
            end
            return true
        else
            local parent_header = table.concat(path, ".", 1, #path - 1)
            local sec = find_section(ast, parent_header)
            if sec then
                for idx, ent in ipairs(sec.entries) do
                    if ent.key == last_seg then
                        table.remove(sec.entries, idx)
                        break
                    end
                end
                for idx, line in ipairs(sec.lines) do
                    if line.kind == "entry" and line.key == last_seg then
                        table.remove(sec.lines, idx)
                        break
                    end
                end
            end
            return true
        end
    elseif kind == "ensure_object" then
        local existing = mutator.resolve_node(ast, path)
        if existing then
            if existing.kind == "object" then
                return true
            else
                return false, errors.conflict(path, "object", existing.kind)
            end
        end
        local header_name = table.concat(path, ".")
        ensure_section(ast, header_name)
        return true
    elseif kind == "ensure_array" then
        local existing = mutator.resolve_node(ast, path)
        if existing then
            if existing.kind == "array" then
                return true
            else
                return false, errors.conflict(path, "array", existing.kind)
            end
        end
        -- create array entry
        if #path == 1 then
            local root_sec = ast.sections[1]
            local ent = {
                kind = "entry",
                key = tostring(last_seg),
                value = { kind = "array", elements = {} },
            }
            table.insert(root_sec.lines, ent)
            table.insert(root_sec.entries, ent)
            return true
        else
            local parent_header = table.concat(path, ".", 1, #path - 1)
            local sec = ensure_section(ast, parent_header)
            local ent = {
                kind = "entry",
                key = tostring(last_seg),
                value = { kind = "array", elements = {} },
            }
            table.insert(sec.lines, ent)
            table.insert(sec.entries, ent)
            return true
        end
    elseif kind == "ensure" then
        local existing = mutator.resolve_node(ast, path)
        if not existing then
            return mutator.apply(ast, { kind = "set", path = path, value = mut.value })
        end
        return true
    elseif kind == "merge" then
        local target = mutator.resolve_node(ast, path)
        if not target then
            mutator.apply(ast, { kind = "ensure_object", path = path })
            target = mutator.resolve_node(ast, path)
        end
        if target.kind ~= "object" then
            return false, errors.conflict(path, "object", target.kind)
        end
        if type(mut.value) == "table" then
            for k, v in pairs(mut.value) do
                local sub_path = { table.unpack(path) }
                table.insert(sub_path, tostring(k))
                mutator.apply(ast, { kind = "set", path = sub_path, value = v })
            end
        end
        return true
    elseif kind == "append" then
        local target = mutator.resolve_node(ast, path)
        if not target then
            mutator.apply(ast, { kind = "ensure_array", path = path })
            target = mutator.resolve_node(ast, path)
        end
        if target.kind ~= "array" then
            return false, errors.conflict(path, "array", target.kind)
        end
        table.insert(target.elements, lua_to_toml_val(mut.value))
        return true
    elseif kind == "append_unique" then
        local target = mutator.resolve_node(ast, path)
        if not target then
            mutator.apply(ast, { kind = "ensure_array", path = path })
            target = mutator.resolve_node(ast, path)
        end
        if target.kind ~= "array" then
            return false, errors.conflict(path, "array", target.kind)
        end

        local val = mut.value
        local found = false
        for _, el in ipairs(target.elements or {}) do
            local el_val = toml_val_to_lua(el)
            if mut.key and type(el_val) == "table" and type(val) == "table" then
                if el_val[mut.key] == val[mut.key] and val[mut.key] ~= nil then
                    found = true
                    break
                end
            else
                if mutation_mod.deep_equal(el_val, val) then
                    found = true
                    break
                end
            end
        end

        if not found then
            table.insert(target.elements, lua_to_toml_val(val))
        end
        return true
    end

    return false, errors.error("unsupported_mutation", "Unsupported mutation kind: " .. tostring(kind), path)
end

return mutator
