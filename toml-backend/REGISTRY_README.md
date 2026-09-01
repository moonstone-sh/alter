# Alter TOML backend

`moonstone/alter-toml` implements Alter’s backend protocol for TOML documents.

```sh
moon add moonstone/alter moonstone/alter-toml
```

```lua
local alter = require("alter")
local toml = require("alter_toml")

local doc = assert(alter.open("tool.toml", { backend = toml }))
doc:at("workspace", "library"):ensure_array():append_unique("./lua")
assert(doc:commit())
```

The backend declares support for comments, ordering, formatting, and minimal edits. It supports semantic table, array, scalar, and nested-mutation operations through the common Alter host. Duplicate keys are not preserved; wrong-kind operations return structured conflicts rather than silently replacing data.
