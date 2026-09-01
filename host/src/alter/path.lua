local path_mod = {}

function path_mod.normalize(...)
    local args = { ... }
    local res = {}

    local function append_segment(seg)
        if type(seg) == "table" then
            for _, sub in ipairs(seg) do
                append_segment(sub)
            end
        elseif type(seg) == "string" then
            table.insert(res, seg)
        elseif type(seg) == "number" then
            local int_val = math.floor(seg)
            if int_val < 1 then
                error("Invalid path segment: integer index must be >= 1, got " .. tostring(seg))
            end
            table.insert(res, int_val)
        else
            error("Invalid path segment type: expected string or integer >= 1, got " .. type(seg))
        end
    end

    for _, a in ipairs(args) do
        append_segment(a)
    end

    return res
end

function path_mod.join(base, ...)
    local res = {}
    if type(base) == "table" then
        for _, seg in ipairs(base) do
            table.insert(res, seg)
        end
    end
    local extra = path_mod.normalize(...)
    for _, seg in ipairs(extra) do
        table.insert(res, seg)
    end
    return res
end

function path_mod.equals(p1, p2)
    if not p1 or not p2 then return p1 == p2 end
    if #p1 ~= #p2 then return false end
    for i = 1, #p1 do
        if p1[i] ~= p2[i] then return false end
    end
    return true
end

function path_mod.is_prefix(prefix, full)
    if #prefix > #full then return false end
    for i = 1, #prefix do
        if prefix[i] ~= full[i] then return false end
    end
    return true
end

function path_mod.to_string(p)
    if not p or #p == 0 then return "/" end
    local parts = {}
    for _, seg in ipairs(p) do
        if type(seg) == "number" then
            table.insert(parts, "[" .. tostring(seg) .. "]")
        else
            if #parts > 0 and not parts[#parts]:match("%]$") then
                table.insert(parts, "." .. tostring(seg))
            else
                table.insert(parts, tostring(seg))
            end
        end
    end
    return table.concat(parts, "")
end

function path_mod.clone(p)
    local res = {}
    for i, seg in ipairs(p or {}) do
        res[i] = seg
    end
    return res
end

return path_mod
