local v = require("valua")
local contracts = require("contracts")
local alter = require("alter")

local conformance = {}

local function assert_contract(schema, data, label)
    local ok, res = pcall(function() return v.safe_parse(schema, data) end)
    if not ok or (res and not res.success) then
        local issues_str = ""
        if res and res.issues then
            local buf = {}
            for _, iss in ipairs(res.issues) do
                table.insert(buf, string.format("  - %s: %s", iss.path and table.concat(iss.path, ".") or "<root>", iss.message or "invalid"))
            end
            issues_str = table.concat(buf, "\n")
        end
        error(string.format("Contract violation for %s:\n%s", label or "data", issues_str))
    end
end

local function assert_backend_document(value)
    assert(type(value) == "table", "BackendDocument must be a table")
    for _, method in ipairs({ "resolve", "kind_at", "value_at", "apply", "render", "clone" }) do
        assert(type(value[method]) == "function", "BackendDocument is missing method '" .. method .. "'")
    end
end

function conformance.run(opts)
    local backend = opts.backend
    assert(backend, "conformance.run requires 'backend'")

    local total = 0
    local passed = 0
    local failures = {}

    local function test(name, fn)
        total = total + 1
        local ok, err = pcall(fn)
        if ok then
            passed = passed + 1
        else
            table.insert(failures, { name = name, error = tostring(err) })
            io.stderr:write(string.format("  [FAIL] %s: %s\n", name, tostring(err)))
        end
    end

    -- 1. Capabilities Contract
    test("Backend capabilities match Valua contract", function()
        assert_contract(contracts.BackendCapabilities, backend.capabilities, "BackendCapabilities")
    end)

    -- 2. Parsing and basic document creation
    test("Parse empty text produces BackendDocument", function()
        local doc, err = alter.parse(opts.empty_text or "", backend)
        assert(doc, "Failed to parse empty document: " .. tostring(err and err.message))
        local backend_doc, backend_err = backend.parse(opts.empty_text or "")
        assert(backend_doc, "Backend.parse failed: " .. tostring(backend_err and backend_err.message))
        assert_backend_document(backend_doc)
    end)

    -- 3. Navigation never mutates
    test("Navigation does not stage mutations or change output", function()
        local doc = alter.parse(opts.sample_text or '{"key": "value"}', backend)
        local before_muts = #doc:mutations()
        assert(before_muts == 0, "Initial mutations should be empty")

        -- navigate deeply
        local c = doc:at("non_existent", "deep", "field")
        assert(c:exists() == false, "Non existent path should not exist")
        assert(c:kind() == "none", "Non existent path kind should be none")
        assert(c:get() == nil, "Non existent path value should be nil")

        assert(#doc:mutations() == 0, "Navigation must not stage any mutations")
        assert(doc:changed() == false, "Navigation must not mark document as changed")
    end)

    -- 4. Mutation IR conformance & all 8 operations
    test("Mutation IR set scalar and nested", function()
        local doc = alter.parse(opts.empty_text or "{}", backend)
        doc:at("workspace"):ensure_object():at("name"):set("alter-test")
        
        local muts = doc:mutations()
        assert(#muts == 2, "Expected 2 mutations staged")
        for _, m in ipairs(muts) do
            assert_contract(contracts.Mutation, m, "Mutation")
        end

        local text, render_res = doc:render()
        assert(render_res.changed == true, "Expected changed = true")
        assert_contract(contracts.RenderResult, render_res, "RenderResult")
        assert(text:find("alter%-test"), "Rendered text should contain value")
    end)

    test("Mutation IR ensure_object & ensure_array", function()
        local doc = alter.parse(opts.empty_text or "{}", backend)
        doc:at("runtime"):ensure_object():at("plugins"):ensure_array()
        
        local text, render_res = doc:render()
        assert(render_res.changed == true, "Expected changed = true")
        assert(text:find("runtime"), "Rendered text should contain runtime")
        assert(text:find("plugins"), "Rendered text should contain plugins")
    end)

    test("Mutation IR append & append_unique", function()
        local doc = alter.parse(opts.empty_text or "{}", backend)
        doc:at("libs"):ensure_array():append("lib_a"):append_unique("lib_b"):append_unique("lib_a")
        
        local text, res = doc:render()
        assert(res.changed == true)
        
        -- Parse result again and check that lib_a is only present once in libs
        local doc2 = alter.parse(text, backend)
        local val = doc2:at("libs"):get()
        assert(type(val) == "table", "libs should be array")
        local count_a = 0
        for _, it in ipairs(val) do
            if it == "lib_a" then count_a = count_a + 1 end
        end
        assert(count_a == 1, "append_unique should not add duplicate lib_a")
    end)

    test("Mutation IR merge into object", function()
        local doc = alter.parse(opts.sample_text or '{"user": {"name": "Alice"}}', backend)
        doc:at("user"):merge({ age = 30, city = "Wonderland" })
        local text, res = doc:render()
        assert(res.changed == true)
        assert(text:find("30") and text:find("Wonderland"), "Merged keys should be present")
    end)

    test("Mutation IR remove key", function()
        local doc = alter.parse(opts.remove_sample_text or '{"a": 1, "b": 2}', backend)
        doc:at("a"):remove()
        local text, res = doc:render()
        assert(res.changed == true)
        local doc2 = alter.parse(text, backend)
        assert(doc2:at("a"):exists() == false, "Key 'a' should be removed")
        assert(doc2:at("b"):exists() == true, "Key 'b' should remain")
    end)

    test("Idempotence on repeat execution", function()
        local doc = alter.parse(opts.empty_text or "{}", backend)
        doc:at("workspace"):ensure_object():at("library"):ensure_array():append_unique("/path/to/lib")
        
        local commit1 = doc:commit()
        assert(commit1.changed == true, "First commit should be changed = true")
        assert_contract(contracts.CommitResult, commit1, "CommitResult")

        -- Second run on the committed state
        local doc2 = alter.parse(commit1.text, backend)
        doc2:at("workspace"):ensure_object():at("library"):ensure_array():append_unique("/path/to/lib")
        
        local commit2 = doc2:commit()
        assert(commit2.changed == false, "Second commit must be changed = false (idempotent)")
        assert(commit2.bytes_written == 0, "No bytes should be written on idempotent run")
        assert(commit2.text == commit1.text, "Text must be byte-identical on idempotent run")
    end)

    test("Structured Conflict when wrong kind encountered", function()
        -- Setting a scalar then calling ensure_object on it
        local doc = alter.parse(opts.scalar_conflict_text or '{"runtime": "string_value"}', backend)
        doc:at("runtime"):ensure_object()
        
        local text, err = doc:render()
        assert(text == nil, "Render should fail on conflict")
        assert(err ~= nil, "Conflict error must be returned")
        assert_contract(contracts.Conflict, err, "Conflict")
        assert(err.kind == "conflict", "Error kind should be 'conflict'")
        assert(err.expected == "object", "Expected object")
    end)

    test("Document rollback clears staged mutations", function()
        local doc = alter.parse(opts.empty_text or "{}", backend)
        doc:at("temp"):set(123)
        assert(#doc:mutations() == 1)
        doc:rollback()
        assert(#doc:mutations() == 0)
        assert(doc:changed() == false)
    end)

    return {
        total = total,
        passed = passed,
        failures = failures,
    }
end

return conformance
