local json_parser = require("alter_json.parser")
local errors = require("alter.errors")

local parser = {}

---Replace JSONC comments with whitespace while preserving line positions.
---The original comment tokens are retained by the document for stable content
---preservation even when a surrounding JSON value is rewritten.
local function strip_comments(text)
    local out, comments = {}, {}
    local i, len, in_string, escaped = 1, #text, false, false
    while i <= len do
        local c, next_c = text:sub(i, i), text:sub(i + 1, i + 1)
        if in_string then
            out[#out + 1] = c
            if escaped then escaped = false
            elseif c == "\\" then escaped = true
            elseif c == '"' then in_string = false end
            i = i + 1
        elseif c == '"' then
            in_string = true
            out[#out + 1] = c
            i = i + 1
        elseif c == "/" and next_c == "/" then
            local start = i
            while i <= len and text:sub(i, i) ~= "\n" do
                i = i + 1
            end
            comments[#comments + 1] = text:sub(start, i - 1)
        elseif c == "/" and next_c == "*" then
            local start = i
            i = i + 2
            while i <= len - 1 and not (text:sub(i, i) == "*" and text:sub(i + 1, i + 1) == "/") do
                local ch = text:sub(i, i)
                if ch == "\n" then out[#out + 1] = "\n" end
                i = i + 1
            end
            if i > len - 1 then return nil, "unterminated block comment" end
            i = i + 2
            comments[#comments + 1] = text:sub(start, i - 1)
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out), comments
end

function parser.parse(text)
    local json, comments_or_err = strip_comments(text)
    if not json then
        return nil, errors.error("parse_error", "Invalid JSONC: " .. comments_or_err)
    end
    local ok, ast_or_err = pcall(json_parser.parse, json)
    if not ok then
        return nil, errors.error("parse_error", "Invalid JSONC: " .. tostring(ast_or_err))
    end
    return ast_or_err, comments_or_err
end

return parser
