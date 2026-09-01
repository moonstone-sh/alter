local ballad = require("ballad")

return ballad.partiture(function(p)
    local moonstone = p:use(ballad.plugins.moonstone)
    local convention = ballad.conventions
    local project = moonstone.project({ root = "." })
    local artifact = moonstone.registry.source_package(project, {
        collect = {
            lua_modules = {
                convention.tree("src", {
                    prefix = "alter_json",
                    strip_prefix = "alter_json/",
                    root_module = "alter_json.lua",
                    overrides = { ["alter-json.lua"] = "alter-json.lua" },
                }),
            },
        },
    })
    p.sink.artifact(artifact, { out = "dist/registry", product = "package" })
end)
