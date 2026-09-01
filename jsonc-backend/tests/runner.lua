package.path = "host/src/?.lua;host/src/?/init.lua;json-backend/src/?.lua;json-backend/src/?/init.lua;jsonc-backend/src/?.lua;jsonc-backend/src/?/init.lua;../host/src/?.lua;../host/src/?/init.lua;../json-backend/src/?.lua;../json-backend/src/?/init.lua;src/?.lua;src/?/init.lua;" .. package.path

local alter = require("alter")
local jsonc = require("alter_jsonc")

for name in pairs(package.loaded) do
    assert(not name:match("^valua"), "alter-jsonc loaded Valua at runtime: " .. name)
end

local text = [[// project settings
{
  /* existing tooling */
  "runtime": {
    "plugin": ["existing-plugin.lua"]
  }
}
]]

local doc = assert(alter.parse(text, jsonc))
doc:at("runtime"):ensure_object():at("version"):set("Lua 5.4")
doc:at("runtime", "plugin"):ensure_array():append_unique("valua-plugin.lua")
local result = assert(doc:commit())
assert(result.changed)
assert(result.text:find("// project settings", 1, true))
assert(result.text:find("/* existing tooling */", 1, true))

local doc2 = assert(alter.parse(result.text, jsonc))
doc2:at("runtime"):ensure_object():at("version"):set("Lua 5.4")
doc2:at("runtime", "plugin"):ensure_array():append_unique("valua-plugin.lua")
local again = assert(doc2:commit())
assert(not again.changed)
assert(again.text == result.text)
print("JSONC backend tests passed")
