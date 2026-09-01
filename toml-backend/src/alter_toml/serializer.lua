local serializer = {}

local function format_val(val_node)
    if val_node.kind == "string" then
        return '"' .. val_node.value:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
    elseif val_node.kind == "number" or val_node.kind == "boolean" then
        return tostring(val_node.value)
    elseif val_node.kind == "array" then
        local parts = {}
        for _, el in ipairs(val_node.elements or {}) do
            table.insert(parts, format_val(el))
        end
        return "[" .. table.concat(parts, ", ") .. "]"
    elseif val_node.kind == "object" then
        local parts = {}
        for _, ent in ipairs(val_node.entries or {}) do
            table.insert(parts, string.format("%s = %s", ent.key, format_val(ent.value)))
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return tostring(val_node.raw or val_node.value)
end

serializer.format_val = format_val

function serializer.serialize(ast)
    local out_lines = {}
    for _, sec in ipairs(ast.sections) do
        for _, line_item in ipairs(sec.lines) do
            if line_item.kind == "raw" or line_item.kind == "header" then
                table.insert(out_lines, line_item.text)
            elseif line_item.kind == "entry" then
                local formatted = string.format("%s = %s", line_item.key, format_val(line_item.value))
                if line_item.comment then
                    formatted = formatted .. " " .. line_item.comment
                end
                table.insert(out_lines, formatted)
            end
        end
    end
    return table.concat(out_lines, "\n") .. "\n"
end

return serializer
