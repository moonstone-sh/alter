-- LuaLS also loads Alter outside Moonstone, where no flavor searcher exists.
if package.config:sub(1, 1) == "\\" then return require("alter.file_replace@windows") end
return os.rename
