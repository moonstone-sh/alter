local alter = require("alter")
local errors = require("alter.errors")
local mutation_mod = require("alter.mutation")

local mutator = {}

local function value_to_ast(val, indent_step)
    indent_step = indent_step or "  "
    if val == nil or val == alter.NULL then
        return { kind = "null", value = alter.NULL, raw = "null" }
    end
    local t = type(val)
    if t == "string" then
        return { kind = "string", value = val }
    elseif t == "number" then
        return { kind = "number", value = val }
    elseif t == "boolean" then
        return { kind = "boolean", value = val }
    elseif t == "table" then
        -- Check if array
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
                table.insert(elements, value_to_ast(val[i], indent_step))
            end
            return { kind = "array", elements = elements, multiline = true, indent = indent_step }
        elseif count == 0 and val._is_array then
            return { kind = "array", elements = {}, multiline = false, indent = indent_step }
        else
            local entries = {}
            for k, v in pairs(val) do
                if k ~= "_is_array" then
                    table.insert(entries, {
                        key = tostring(k),
                        value = value_to_ast(v, indent_step),
                    })
                end
            end
            return { kind = "object", entries = entries, multiline = true, indent = indent_step }
        end
    end
    return { kind = "null", value = alter.NULL, raw = "null" }
end

local function ast_to_lua_value(node)
    if not node then return nil end
    if node.kind == "string" or node.kind == "number" or node.kind == "boolean" then
        return node.value
    elseif node.kind == "null" then
        return alter.NULL
    elseif node.kind == "array" then
        local res = {}
        for i, el in ipairs(node.elements) do
            res[i] = ast_to_lua_value(el)
        end
        return res
    elseif node.kind == "object" then
        local res = {}
        for _, entry in ipairs(node.entries) do
            res[entry.key] = ast_to_lua_value(entry.value)
        end
        return res
    end
    return nil
end

local function clone_ast(node)
    if type(node) ~= "table" then return node end
    local c = {
        kind = node.kind,
        value = node.value,
        raw = node.raw,
        multiline = node.multiline,
        indent = node.indent,
    }
    if node.elements then
        c.elements = {}
        for i, el in ipairs(node.elements) do
            c.elements[i] = clone_ast(el)
        end
    end
    if node.entries then
        c.entries = {}
        for i, entry in ipairs(node.entries) do
            c.entries[i] = {
                key = entry.key,
                raw_key = entry.raw_key,
                value = clone_ast(entry.value),
            }
        end
    end
    return c
end

mutator.value_to_ast = value_to_ast
mutator.ast_to_lua_value = ast_to_lua_value
mutator.clone_ast = clone_ast

function mutator.resolve_node(root_node, path)
    local cur = root_node
    for _, seg in ipairs(path or {}) do
        if not cur then return nil end
        if type(seg) == "string" then
            if cur.kind ~= "object" then return nil end
            local found = nil
            for _, entry in ipairs(cur.entries) do
                if entry.key == seg then
                    found = entry.value
                    break
                end
            end
            cur = found
        elseif type(seg) == "number" then
            if cur.kind ~= "array" then return nil end
            cur = cur.elements[seg]
        else
            return nil
        end
    end
    return cur
end

function mutator.apply(root_node, mut)
    local path = mut.path or {}
    local kind = mut.kind

    if #path == 0 then
        if kind == "set" then
            local new_ast = value_to_ast(mut.value, root_node.indent)
            for k in pairs(root_node) do root_node[k] = nil end
            for k, v in pairs(new_ast) do root_node[k] = v end
            return true
        elseif kind == "ensure_object" then
            if root_node.kind ~= "object" then
                return false, errors.conflict(path, "object", root_node.kind)
            end
            return true
        elseif kind == "ensure_array" then
            if root_node.kind ~= "array" then
                return false, errors.conflict(path, "array", root_node.kind)
            end
            return true
        end
    end

    -- Navigate parent
    local cur = root_node
    for i = 1, #path - 1 do
        local seg = path[i]
        local next_seg = path[i + 1]

        if type(seg) == "string" then
            if cur.kind ~= "object" then
                return false, errors.conflict({ table.unpack(path, 1, i) }, "object", cur.kind)
            end
            local found = nil
            for _, entry in ipairs(cur.entries) do
                if entry.key == seg then
                    found = entry.value
                    break
                end
            end
            if not found then
                local new_container
                if type(next_seg) == "number" then
                    new_container = { kind = "array", elements = {}, multiline = true, indent = root_node.indent }
                else
                    new_container = { kind = "object", entries = {}, multiline = true, indent = root_node.indent }
                end
                table.insert(cur.entries, {
                    key = seg,
                    value = new_container,
                })
                cur = new_container
            else
                cur = found
            end
        elseif type(seg) == "number" then
            if cur.kind ~= "array" then
                return false, errors.conflict({ table.unpack(path, 1, i) }, "array", cur.kind)
            end
            local el = cur.elements[seg]
            if not el then
                return false, errors.error("index_out_of_bounds", "Array index out of bounds: " .. tostring(seg), path)
            end
            cur = el
        end
    end

    local last_seg = path[#path]

    if kind == "set" then
        if type(last_seg) == "string" then
            if cur.kind ~= "object" then
                return false, errors.conflict(path, "object", cur.kind)
            end
            local ast_val = value_to_ast(mut.value, root_node.indent)
            local updated = false
            for _, entry in ipairs(cur.entries) do
                if entry.key == last_seg then
                    entry.value = ast_val
                    updated = true
                    break
                end
            end
            if not updated then
                table.insert(cur.entries, {
                    key = last_seg,
                    value = ast_val,
                })
            end
            return true
        elseif type(last_seg) == "number" then
            if cur.kind ~= "array" then
                return false, errors.conflict(path, "array", cur.kind)
            end
            local ast_val = value_to_ast(mut.value, root_node.indent)
            cur.elements[last_seg] = ast_val
            return true
        end
    elseif kind == "remove" then
        if type(last_seg) == "string" then
            if cur.kind == "object" then
                for idx, entry in ipairs(cur.entries) do
                    if entry.key == last_seg then
                        table.remove(cur.entries, idx)
                        break
                    end
                end
            end
            return true
        elseif type(last_seg) == "number" then
            if cur.kind == "array" then
                table.remove(cur.elements, last_seg)
            end
            return true
        end
    elseif kind == "ensure" then
        local existing = mutator.resolve_node(cur, { last_seg })
        if not existing then
            return mutator.apply(root_node, { kind = "set", path = path, value = mut.value })
        end
        return true
    elseif kind == "ensure_object" then
        local existing = mutator.resolve_node(cur, { last_seg })
        if not existing then
            return mutator.apply(root_node, { kind = "set", path = path, value = {} })
        elseif existing.kind == "object" then
            return true
        else
            return false, errors.conflict(path, "object", existing.kind)
        end
    elseif kind == "ensure_array" then
        local existing = mutator.resolve_node(cur, { last_seg })
        if not existing then
            local arr_ast = { kind = "array", elements = {}, multiline = true, indent = root_node.indent }
            if type(last_seg) == "string" then
                if cur.kind ~= "object" then return false, errors.conflict(path, "object", cur.kind) end
                table.insert(cur.entries, { key = last_seg, value = arr_ast })
                return true
            end
        elseif existing.kind == "array" then
            return true
        else
            return false, errors.conflict(path, "array", existing.kind)
        end
    elseif kind == "merge" then
        local target = mutator.resolve_node(cur, { last_seg })
        if not target then
            mutator.apply(root_node, { kind = "ensure_object", path = path })
            target = mutator.resolve_node(cur, { last_seg })
        end
        if target.kind ~= "object" then
            return false, errors.conflict(path, "object", target.kind)
        end
        if type(mut.value) == "table" then
            for k, v in pairs(mut.value) do
                local sub_path = { table.unpack(path) }
                table.insert(sub_path, tostring(k))
                mutator.apply(root_node, { kind = "set", path = sub_path, value = v })
            end
        end
        return true
    elseif kind == "append" then
        local target = mutator.resolve_node(cur, { last_seg })
        if not target then
            local arr_ast = { kind = "array", elements = {}, multiline = true, indent = root_node.indent }
            if type(last_seg) == "string" then
                if cur.kind ~= "object" then return false, errors.conflict(path, "object", cur.kind) end
                table.insert(cur.entries, { key = last_seg, value = arr_ast })
                target = arr_ast
            end
        end
        if target.kind ~= "array" then
            return false, errors.conflict(path, "array", target.kind)
        end
        table.insert(target.elements, value_to_ast(mut.value, root_node.indent))
        return true
    elseif kind == "append_unique" then
        local target = mutator.resolve_node(cur, { last_seg })
        if not target then
            local arr_ast = { kind = "array", elements = {}, multiline = true, indent = root_node.indent }
            if type(last_seg) == "string" then
                if cur.kind ~= "object" then return false, errors.conflict(path, "object", cur.kind) end
                table.insert(cur.entries, { key = last_seg, value = arr_ast })
                target = arr_ast
            end
        end
        if target.kind ~= "array" then
            return false, errors.conflict(path, "array", target.kind)
        end
        
        local val = mut.value
        local found = false
        for _, el in ipairs(target.elements) do
            local el_val = ast_to_lua_value(el)
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
            table.insert(target.elements, value_to_ast(val, root_node.indent))
        end
        return true
    end

    return false, errors.error("unsupported_mutation", "Unsupported mutation: " .. tostring(kind), path)
end

return mutator
