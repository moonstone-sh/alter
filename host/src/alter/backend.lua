local errors = require("alter.errors")

local backend_mod = {}

function backend_mod.validate_backend(backend)
    if type(backend) ~= "table" then
        return false, errors.error("invalid_backend", "Backend must be a table")
    end
    if type(backend.name) ~= "string" then
        return false, errors.error("invalid_backend", "Backend must have a string 'name'")
    end
    if type(backend.capabilities) ~= "table" then
        return false, errors.error("invalid_backend", "Backend must have a 'capabilities' table")
    end
    if type(backend.parse) ~= "function" then
        return false, errors.error("invalid_backend", "Backend must provide a 'parse' function")
    end
    return true
end

return backend_mod
