local serializer = {}

local function escape_str(s)
    local res = s:gsub('\\', '\\\\')
                 :gsub('"', '\\"')
                 :gsub('\n', '\\n')
                 :gsub('\r', '\\r')
                 :gsub('\t', '\\t')
    return '"' .. res .. '"'
end

function serializer.serialize_node(node, current_indent, indent_step)
    current_indent = current_indent or ""
    indent_step = indent_step or "  "

    if node.kind == "string" then
        return escape_str(node.value)
    elseif node.kind == "number" or node.kind == "boolean" then
        return tostring(node.value)
    elseif node.kind == "null" then
        return "null"
    elseif node.kind == "array" then
        if #node.elements == 0 then
            return "[]"
        end
        local next_indent = current_indent .. indent_step
        local lines = {}
        for i, el in ipairs(node.elements) do
            local el_str = serializer.serialize_node(el, next_indent, indent_step)
            local comma = (i < #node.elements) and "," or ""
            table.insert(lines, next_indent .. el_str .. comma)
        end
        return "[\n" .. table.concat(lines, "\n") .. "\n" .. current_indent .. "]"
    elseif node.kind == "object" then
        if #node.entries == 0 then
            return "{}"
        end
        local next_indent = current_indent .. indent_step
        local lines = {}
        for i, entry in ipairs(node.entries) do
            local val_str = serializer.serialize_node(entry.value, next_indent, indent_step)
            local comma = (i < #node.entries) and "," or ""
            table.insert(lines, next_indent .. escape_str(entry.key) .. ": " .. val_str .. comma)
        end
        return "{\n" .. table.concat(lines, "\n") .. "\n" .. current_indent .. "}"
    end
    return "null"
end

function serializer.serialize(root_node)
    local indent_step = root_node.indent or "  "
    local s = serializer.serialize_node(root_node, "", indent_step)
    return s .. "\n"
end

return serializer
