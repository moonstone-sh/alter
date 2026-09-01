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
                    prefix = "alter_toml",
                    strip_prefix = "alter_toml/",
                    root_module = "alter_toml.lua",
                    overrides = { ["alter-toml.lua"] = "alter-toml.lua" },
                }),
            },
        },
    })
    p.sink.artifact(artifact, { out = "dist/registry", product = "package" })
end)
