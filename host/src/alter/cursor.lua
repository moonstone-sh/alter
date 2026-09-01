local path_mod = require("alter.path")
local mutation_mod = require("alter.mutation")

local Cursor = {}
Cursor.__index = Cursor

function Cursor.new(doc, path)
    return setmetatable({
        _doc = doc,
        _path = path or {},
    }, Cursor)
end

function Cursor:at(...)
    local target_path = path_mod.join(self._path, ...)
    return Cursor.new(self._doc, target_path)
end

function Cursor:path()
    return path_mod.clone(self._path)
end

function Cursor:doc()
    return self._doc
end

function Cursor:exists()
    return self:kind() ~= "none"
end

function Cursor:kind()
    return self._doc:kind_at(self._path)
end

function Cursor:get()
    return self._doc:value_at(self._path)
end

function Cursor:set(value)
    self._doc:stage(mutation_mod.create("set", path_mod.clone(self._path), value))
    return self
end

function Cursor:remove()
    self._doc:stage(mutation_mod.create("remove", path_mod.clone(self._path)))
    return self
end

function Cursor:ensure(value)
    self._doc:stage(mutation_mod.create("ensure", path_mod.clone(self._path), value))
    return self
end

function Cursor:ensure_object()
    self._doc:stage(mutation_mod.create("ensure_object", path_mod.clone(self._path)))
    return self
end

function Cursor:ensure_array()
    self._doc:stage(mutation_mod.create("ensure_array", path_mod.clone(self._path)))
    return self
end

function Cursor:merge(value, opts)
    self._doc:stage(mutation_mod.create("merge", path_mod.clone(self._path), value, opts))
    return self
end

function Cursor:append(value)
    self._doc:stage(mutation_mod.create("append", path_mod.clone(self._path), value))
    return self
end

function Cursor:append_unique(value, key)
    self._doc:stage(mutation_mod.create("append_unique", path_mod.clone(self._path), value, { key = key }))
    return self
end

return Cursor
