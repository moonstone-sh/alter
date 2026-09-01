# Alter JSON backend

`moonstone/alter-json` implements Alter’s backend protocol for strict JSON.

```sh
moon add moonstone/alter moonstone/alter-json
```

```lua
local alter = require("alter")
local json = require("alter_json")

local doc = assert(alter.parse('{"workspace":{"library":[]}}', json))
doc:at("workspace", "library"):append_unique("./lua")
print(assert(doc:render()))
```

The backend supports objects, arrays, scalars, nested mutations, deterministic staged operations, idempotent `append_unique`, and structured wrong-kind conflicts.

It accepts strict JSON only. JSON comments are unsupported, duplicate keys are not preserved, and input using JSONC syntax should use `moonstone/alter-jsonc` instead. The backend declares ordering, formatting, and minimal-edit capabilities.
