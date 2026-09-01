local errors = {}

function errors.conflict(path, expected, actual, message)
    return {
        kind = "conflict",
        path = path or {},
        expected = expected or "unknown",
        actual = actual or "unknown",
        message = message or string.format(
            "Conflict at path '%s': expected %s, got %s",
            table.concat(path or {}, "."),
            expected or "unknown",
            actual or "unknown"
        ),
    }
end

function errors.error(kind, message, path, cause)
    return {
        kind = kind or "error",
        message = message or "An unknown error occurred",
        path = path,
        cause = cause,
    }
end

function errors.is_conflict(obj)
    return type(obj) == "table" and obj.kind == "conflict"
end

function errors.is_error(obj)
    return type(obj) == "table" and (obj.kind == "conflict" or type(obj.message) == "string")
end

return errors
