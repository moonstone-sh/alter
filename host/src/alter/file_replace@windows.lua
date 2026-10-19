-- Windows CRT rename cannot replace an existing file. File.Replace performs
-- replacement without a delete gap; failures leave the destination intact.
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(bytes)
    local result = {}
    for i = 1, #bytes, 3 do
        local a, b, c = bytes:byte(i, i + 2)
        b, c = b or 0, c or 0
        local n = a * 65536 + b * 256 + c
        for shift = 18, 0, -6 do
            local index = math.floor(n / 2 ^ shift) % 64 + 1
            result[#result + 1] = alphabet:sub(index, index)
        end
        if i + 1 > #bytes then result[#result - 1] = "=" end
        if i + 2 > #bytes then result[#result] = "=" end
    end
    return table.concat(result)
end
local function literal(value)
    return "[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" .. base64(value) .. "'))"
end
return function(source, destination)
    local script = "$ErrorActionPreference='Stop';$s=" .. literal(source) .. ";$d=" .. literal(destination)
        .. ";if([IO.File]::Exists($d)){[IO.File]::Replace($s,$d,$null)}else{[IO.File]::Move($s,$d)}"
    -- EncodedCommand is UTF-16LE. The script itself is ASCII; paths carry UTF-8
    -- inside base64 literals, never cmd syntax or PowerShell interpolation.
    local encoded = base64((script:gsub(".", function(c) return c .. "\0" end)))
    local ok, _, code = os.execute("powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand " .. encoded)
    if ok == true or ok == 0 then return true end
    return nil, "Windows atomic replacement failed (PowerShell exit " .. tostring(code or ok) .. ")"
end
