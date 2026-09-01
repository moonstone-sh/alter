local ballad = require("ballad")

return ballad.partiture(function(p)
    local moonstone = p:use(ballad.plugins.moonstone)
    local convention = ballad.conventions
    local project = moonstone.project({ root = "." })
    local artifact = moonstone.registry.source_package(project, {
        readme = "REGISTRY_README.md",
        collect = {
            lua_modules = {
                convention.tree("src", {
                    prefix = "alter_jsonc",
                    strip_prefix = "alter_jsonc/",
                    root_module = "alter_jsonc.lua",
                    overrides = { ["alter-jsonc.lua"] = "alter-jsonc.lua" },
                }),
            },
        },
    })
    p.sink.artifact(artifact, { out = "dist/registry", product = "package" })
end)
