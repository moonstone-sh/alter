local mutation_mod = {}

local function deep_equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not deep_equal(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function clone_value(v)
    if type(v) ~= "table" then return v end
    local res = {}
    for k, val in pairs(v) do
        res[k] = clone_value(val)
    end
    return res
end

mutation_mod.deep_equal = deep_equal
mutation_mod.clone_value = clone_value

function mutation_mod.create(kind, path, value, opts)
    local mut = {
        kind = kind,
        path = path,
    }
    if value ~= nil then
        mut.value = clone_value(value)
    end
    if opts then
        if opts.deep ~= nil then mut.deep = opts.deep end
        if opts.key ~= nil then mut.key = opts.key end
    end
    return mut
end

function mutation_mod.clone(mut)
    local c = {
        kind = mut.kind,
        path = {},
    }
    for i, seg in ipairs(mut.path) do
        c.path[i] = seg
    end
    if mut.value ~= nil then
        c.value = clone_value(mut.value)
    end
    if mut.deep ~= nil then c.deep = mut.deep end
    if mut.key ~= nil then c.key = mut.key end
    return c
end

return mutation_mod
