# Alter JSONC backend

`moonstone/alter-jsonc` implements Alter’s backend protocol for JSON with line and block comments. It is the appropriate backend for project files such as `.luarc.json` when comment text must survive a semantic update.

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

doc:at("runtime", "plugin"):ensure_array():append_unique("plugin.lua")
assert(doc:commit())
```

v0.1 retains parsed comments verbatim, but it is a structural whole-document renderer: comments are emitted ahead of the rewritten JSONC document. It therefore does **not** promise original comment placement or minimal token-range edits (`minimal_edits = false`). Duplicate keys are unsupported. Ordering and formatting are supported.
