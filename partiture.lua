local ballad = require("ballad")

return ballad.partiture(function(p)
    local moonstone = p:use(ballad.plugins.moonstone)
    local layout = p:use(ballad.plugins.layout)

    local function package_orbit(name)
        return moonstone.orbit(name):partiture("partiture.lua"):run({
            sync = "locked",
            inputs = { "moonstone.toml", "moonstone.lock", "partiture.lua", "src/**" },
        }):product("package")
    end

    local suite = layout.directory({
        { from = package_orbit("host"), to = "alter" },
        { from = package_orbit("json-backend"), to = "alter-json" },
        { from = package_orbit("jsonc-backend"), to = "alter-jsonc" },
        { from = package_orbit("toml-backend"), to = "alter-toml" },
    })
    p.sink.directory(suite, { out = "dist/orbit", file_graph = true, product = "release" })
end)
