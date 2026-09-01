# Alter

Alter is a small Lua host for semantic, transactional edits to structured documents. It separates document intent from format-specific syntax: the host stages a deterministic mutation IR, while a selected backend parses, applies, and renders it.

## Packages

| Package | Lua module | Purpose |
| --- | --- | --- |
| `moonstone/alter` | `alter` | Host API, mutation IR, transactions, LuaCATS protocols, and backend conformance tools. |
| `moonstone/alter-json` | `alter_json` | Strict JSON backend. |
| `moonstone/alter-jsonc` | `alter_jsonc` | JSON-with-comments backend. |
| `moonstone/alter-toml` | `alter_toml` | TOML backend. |

Install the host and only the backend you need:

```sh
moon add moonstone/alter moonstone/alter-jsonc
```

## Example

```lua
local alter = require("alter")
local jsonc = require("alter_jsonc")

local doc = assert(alter.open(".luarc.json", {
    backend = jsonc,
    create = true,
    default_text = "{}\n",
}))

doc:at("runtime")
   :ensure_object()
   :at("plugin")
   :ensure_array()
   :append_unique(".moonstone/env/share/lua/5.4/valua/tooling/luals/plugin.lua")

local result = assert(doc:commit())
print(result.changed)
```

Navigation never creates data. `at(...)` only creates a cursor; `ensure_*`, `set`, `merge`, `append`, and `append_unique` stage explicit mutations. `render()` produces text without writing, while `commit()` writes atomically when a change is required. Repeating an idempotent edit does not rewrite the file.

## Architecture and contracts

The host is format-neutral. JSON, JSONC, and TOML syntax, comments, formatting, ordering, and concrete rendering belong to their backends.

Alter publishes LuaCATS for the host and backend protocols. Its protocol data—paths, mutations, capabilities, errors, conflicts, and commit/render results—has Valua schemas used by contract tests and backend conformance. Valua is development and test tooling only: requiring Alter or any backend does not require or load Valua in production.

Third-party backends implement `alter.Backend` and can run the reusable suite:

```lua
local conformance = require("alter.testing.backend_conformance")

conformance.run({
    backend = require("my_backend"),
    fixtures = fixtures,
})
```

## Backend guarantees

| Backend | Comments | Ordering / formatting | Minimal edits |
| --- | --- | --- | --- |
| JSON | Unsupported | Supported | Supported |
| JSONC | Retained as comment text | Supported | Not in v0.1 |
| TOML | Supported | Supported | Supported |

JSONC v0.1 is structural: it retains comments verbatim but rewrites the document and emits retained comments ahead of it. It does not promise original comment placement. See each package’s registry README for precise format notes.
