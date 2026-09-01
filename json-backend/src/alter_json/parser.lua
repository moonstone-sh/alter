local alter = require("alter")

local parser = {}

local function skip_ws(text, pos)
    local len = #text
    while pos <= len do
        local c = text:sub(pos, pos)
        if c == ' ' or c == '\t' or c == '\r' or c == '\n' then
            pos = pos + 1
        else
            break
        end
    end
    return pos
end

local function parse_string(text, pos)
    local len = #text
    local start_pos = pos
    pos = pos + 1 -- skip opening quote
    local buf = {}
    while pos <= len do
        local c = text:sub(pos, pos)
        if c == '\\' then
            local next_c = text:sub(pos + 1, pos + 1)
            if next_c == '"' then table.insert(buf, '"'); pos = pos + 2
            elseif next_c == '\\' then table.insert(buf, '\\'); pos = pos + 2
            elseif next_c == '/' then table.insert(buf, '/'); pos = pos + 2
            elseif next_c == 'b' then table.insert(buf, '\b'); pos = pos + 2
            elseif next_c == 'f' then table.insert(buf, '\f'); pos = pos + 2
            elseif next_c == 'n' then table.insert(buf, '\n'); pos = pos + 2
            elseif next_c == 'r' then table.insert(buf, '\r'); pos = pos + 2
            elseif next_c == 't' then table.insert(buf, '\t'); pos = pos + 2
            elseif next_c == 'u' then
                local hex = text:sub(pos + 2, pos + 5)
                local codepoint = tonumber(hex, 16)
                if codepoint then
                    if codepoint < 128 then
                        table.insert(buf, string.char(codepoint))
                    else
                        table.insert(buf, "?") -- simple fallback
                    end
                end
                pos = pos + 6
            else
                table.insert(buf, next_c)
                pos = pos + 2
            end
        elseif c == '"' then
            pos = pos + 1
            local raw = text:sub(start_pos, pos - 1)
            return {
                kind = "string",
                value = table.concat(buf, ""),
                raw = raw,
            }, pos
        else
            table.insert(buf, c)
            pos = pos + 1
        end
    end
    error("Unterminated string starting at " .. start_pos)
end

local function parse_number(text, pos)
    local len = #text
    local start_pos = pos
    while pos <= len do
        local c = text:sub(pos, pos)
        if (c >= '0' and c <= '9') or c == '-' or c == '+' or c == '.' or c == 'e' or c == 'E' then
            pos = pos + 1
        else
            break
        end
    end
    local raw = text:sub(start_pos, pos - 1)
    local num = tonumber(raw)
    if not num then
        error("Invalid number: " .. raw .. " at " .. start_pos)
    end
    return {
        kind = "number",
        value = num,
        raw = raw,
    }, pos
end

local parse_value

local function parse_array(text, pos, base_indent)
    pos = pos + 1 -- skip '['
    local elements = {}
    local len = #text
    pos = skip_ws(text, pos)
    if pos <= len and text:sub(pos, pos) == ']' then
        return {
            kind = "array",
            elements = elements,
            multiline = false,
            indent = base_indent or "  ",
        }, pos + 1
    end

    local multiline = false
    while pos <= len do
        pos = skip_ws(text, pos)
        if pos > len then break end
        if text:sub(pos, pos) == ']' then
            pos = pos + 1
            break
        end

        local val_node
        val_node, pos = parse_value(text, pos, base_indent)
        table.insert(elements, val_node)

        pos = skip_ws(text, pos)
        if pos <= len and text:sub(pos, pos) == ',' then
            pos = pos + 1
        elseif pos <= len and text:sub(pos, pos) == ']' then
            pos = pos + 1
            break
        end
    end

    return {
        kind = "array",
        elements = elements,
        multiline = true,
        indent = base_indent or "  ",
    }, pos
end

local function parse_object(text, pos, base_indent)
    pos = pos + 1 -- skip '{'
    local entries = {}
    local len = #text
    pos = skip_ws(text, pos)
    if pos <= len and text:sub(pos, pos) == '}' then
        return {
            kind = "object",
            entries = entries,
            multiline = false,
            indent = base_indent or "  ",
        }, pos + 1
    end

    while pos <= len do
        pos = skip_ws(text, pos)
        if pos > len then break end
        if text:sub(pos, pos) == '}' then
            pos = pos + 1
            break
        end

        if text:sub(pos, pos) ~= '"' then
            error("Expected string key in object at position " .. pos)
        end

        local key_node
        key_node, pos = parse_string(text, pos)
        local key = key_node.value

        pos = skip_ws(text, pos)
        if pos > len or text:sub(pos, pos) ~= ':' then
            error("Expected ':' after key in object at position " .. pos)
        end
        pos = pos + 1 -- skip ':'

        pos = skip_ws(text, pos)
        local val_node
        val_node, pos = parse_value(text, pos, base_indent)

        table.insert(entries, {
            key = key,
            raw_key = key_node.raw,
            value = val_node,
        })

        pos = skip_ws(text, pos)
        if pos <= len and text:sub(pos, pos) == ',' then
            pos = pos + 1
        elseif pos <= len and text:sub(pos, pos) == '}' then
            pos = pos + 1
            break
        end
    end

    return {
        kind = "object",
        entries = entries,
        multiline = true,
        indent = base_indent or "  ",
    }, pos
end

parse_value = function(text, pos, base_indent)
    pos = skip_ws(text, pos)
    local len = #text
    if pos > len then error("Unexpected end of JSON input") end

    local c = text:sub(pos, pos)
    if c == '{' then
        return parse_object(text, pos, base_indent)
    elseif c == '[' then
        return parse_array(text, pos, base_indent)
    elseif c == '"' then
        return parse_string(text, pos)
    elseif (c >= '0' and c <= '9') or c == '-' then
        return parse_number(text, pos)
    elseif text:sub(pos, pos + 3) == "true" then
        return { kind = "boolean", value = true, raw = "true" }, pos + 4
    elseif text:sub(pos, pos + 4) == "false" then
        return { kind = "boolean", value = false, raw = "false" }, pos + 5
    elseif text:sub(pos, pos + 3) == "null" then
        return { kind = "null", value = alter.NULL, raw = "null" }, pos + 4
    else
        error("Unexpected character in JSON: '" .. c .. "' at position " .. pos)
    end
end

function parser.parse(text)
    if not text or text:match("^%s*$") then
        return {
            kind = "object",
            entries = {},
            multiline = false,
            indent = "  ",
            is_empty = true,
        }
    end

    local indent = "  "
    local m = text:match("\n([ ]+)[^\n]")
    if m then indent = m end

    local node, pos = parse_value(text, 1, indent)
    return node
end

return parser
