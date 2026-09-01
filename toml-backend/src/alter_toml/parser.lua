local alter = require("alter")

local parser = {}

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function parse_inline_value(str)
    local s = trim(str)
    if s == "true" then return { kind = "boolean", value = true, raw = s } end
    if s == "false" then return { kind = "boolean", value = false, raw = s } end
    
    -- String
    if s:match('^"(.*)"$') then
        local content = s:match('^"(.*)"$')
        return { kind = "string", value = content, raw = s }
    elseif s:match("^'(.*)'$") then
        local content = s:match("^'(.*)'$")
        return { kind = "string", value = content, raw = s }
    end

    -- Number (integer or float)
    local num = tonumber(s)
    if num then
        return { kind = "number", value = num, raw = s }
    end

    -- Array: [ ... ]
    if s:sub(1, 1) == "[" and s:sub(-1) == "]" then
        local inner = s:sub(2, -2)
        local elements = {}
        -- Simple split by comma for inline arrays
        local pos = 1
        local len = #inner
        while pos <= len do
            local next_comma = inner:find(",", pos)
            local item_str
            if next_comma then
                item_str = inner:sub(pos, next_comma - 1)
                pos = next_comma + 1
            else
                item_str = inner:sub(pos)
                pos = len + 1
            end
            local trimmed = trim(item_str)
            if #trimmed > 0 then
                table.insert(elements, parse_inline_value(trimmed))
            end
        end
        return { kind = "array", elements = elements, raw = s }
    end

    -- Inline table: { ... }
    if s:sub(1, 1) == "{" and s:sub(-1) == "}" then
        local inner = s:sub(2, -2)
        local entries = {}
        for part in inner:gmatch("[^,]+") do
            local k, v = part:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
            if k and v then
                local key = trim(k)
                table.insert(entries, {
                    key = key,
                    value = parse_inline_value(v),
                })
            end
        end
        return { kind = "object", entries = entries, raw = s, is_inline = true }
    end

    return { kind = "string", value = s, raw = s }
end

parser.parse_inline_value = parse_inline_value

function parser.parse(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        table.insert(lines, line)
    end
    -- remove trailing empty line if text ended with newline
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines)
    end

    local sections = {}
    local current_section = {
        header = "",
        is_array_table = false,
        lines = {}, -- raw lines and parsed elements
        entries = {},
    }
    table.insert(sections, current_section)

    for line_idx, line in ipairs(lines) do
        local trimmed = trim(line)
        
        -- Comment line or blank line
        if trimmed:sub(1, 1) == "#" or trimmed == "" then
            table.insert(current_section.lines, { kind = "raw", text = line })
        else
            -- Array of tables header: [[table.name]]
            local arr_table_name = trimmed:match("^%[%[([^%]]+)%]%]$")
            if arr_table_name then
                current_section = {
                    header = trim(arr_table_name),
                    is_array_table = true,
                    raw_header = line,
                    lines = { { kind = "header", text = line } },
                    entries = {},
                }
                table.insert(sections, current_section)
            else
                -- Standard table header: [table.name]
                local table_name = trimmed:match("^%[([^%]]+)%]$")
                if table_name then
                    current_section = {
                        header = trim(table_name),
                        is_array_table = false,
                        raw_header = line,
                        lines = { { kind = "header", text = line } },
                        entries = {},
                    }
                    table.insert(sections, current_section)
                else
                    -- Key-value pair
                    local k, eq_ws, v_and_c = line:match("^%s*([^=]+)(%s*=%s*)(.*)$")
                    if k and v_and_c then
                        local key = trim(k)
                        -- separate inline comment if any
                        local val_str = v_and_c
                        local comment = nil
                        local in_q = false
                        for i = 1, #v_and_c do
                            local c = v_and_c:sub(i, i)
                            if c == '"' or c == "'" then in_q = not in_q
                            elseif c == '#' and not in_q then
                                val_str = v_and_c:sub(1, i - 1)
                                comment = v_and_c:sub(i)
                                break
                            end
                        end

                        local val_node = parse_inline_value(val_str)
                        local entry = {
                            kind = "entry",
                            key = key,
                            value = val_node,
                            comment = comment,
                            raw_line = line,
                        }
                        table.insert(current_section.lines, entry)
                        table.insert(current_section.entries, entry)
                    else
                        table.insert(current_section.lines, { kind = "raw", text = line })
                    end
                end
            end
        end
    end

    return {
        kind = "toml_doc",
        sections = sections,
    }
end

return parser
