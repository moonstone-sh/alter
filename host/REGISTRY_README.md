# Alter

`moonstone/alter` is the format-neutral host for transactional structured-document edits in Lua. Install it with one backend, for example:

```sh
moon add moonstone/alter moonstone/alter-jsonc
```

```lua
local alter = require("alter")
local jsonc = require("alter_jsonc")

local doc = assert(alter.open(".luarc.json", {
    backend = jsonc,
    create = true,
    default_text = "{}\n",
}))

doc:at("runtime", "plugin")
   :ensure_array()
   :append_unique("plugin.lua")

local result = assert(doc:commit())
```

`at(...)` only navigates. Mutators stage ordered, inspectable data such as `{ kind = "append_unique", path = { "runtime", "plugin" }, value = "plugin.lua" }`. Use `doc:mutations()` for dry runs or logging, `doc:render()` to obtain text without writing, and `doc:rollback()` to discard staged work.

The public LuaCATS contract includes `alter.Backend`, `alter.BackendDocument`, capability data, mutations, conflicts, errors, and commit results. Backend authors can use the dynamic conformance suite:

```lua
require("alter.testing.backend_conformance").run({
    backend = require("my_backend"),
    fixtures = fixtures,
})
```

Valua schemas are used for development-time contract validation and conformance; Alter does not require Valua at runtime.
