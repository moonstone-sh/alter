local alter = require("alter")
local FakeBackend = require("alter.testing.fake_backend")

describe("Host Document API", function()
    local sample_json = '{"name": "moonstone", "version": 1, "nested": {"count": 10}}'

    describe("Document Creation & Parsing", function()
        it("alter.parse parses text into a Document", function()
            local doc, err = alter.parse(sample_json, FakeBackend)
            assert_nil(err)
            assert_not_nil(doc)
            assert_equal(doc:at("name"):get(), "moonstone")
            assert_equal(doc:at("version"):get(), 1)
            assert_equal(doc:at("nested", "count"):get(), 10)
        end)

        it("alter.create creates an empty Document", function()
            local doc, err = alter.create(FakeBackend)
            assert_nil(err)
            assert_not_nil(doc)
            assert_equal(#doc:mutations(), 0)
            assert_false(doc:at("anything"):exists())
        end)

        it("alter.open loads file from disk", function()
            local tmp_file = "/tmp/alter_test_open_" .. tostring(os.time()) .. ".txt"
            local f = io.open(tmp_file, "w")
            assert_not_nil(f)
            f:write('{"opened": true}')
            f:close()

            local doc, err = alter.open(tmp_file, { backend = FakeBackend })
            assert_nil(err)
            assert_not_nil(doc)
            assert_equal(doc:at("opened"):get(), true)
            os.remove(tmp_file)
        end)

        it("alter.open with create=true handles missing files", function()
            local missing_file = "/tmp/alter_test_missing_" .. tostring(os.time()) .. ".txt"
            os.remove(missing_file)

            local doc, err = alter.open(missing_file, { backend = FakeBackend, create = true, default_text = '{"default": 1}' })
            assert_nil(err)
            assert_not_nil(doc)
            assert_equal(doc:at("default"):get(), 1)
        end)
    end)

    describe("Cursor Navigation & Non-Mutation", function()
        it("navigating existing and missing keys creates no mutations", function()
            local doc = alter.parse(sample_json, FakeBackend)
            assert_equal(#doc:mutations(), 0)

            local c1 = doc:at("name")
            assert_true(c1:exists())
            assert_equal(c1:get(), "moonstone")

            local c2 = doc:at("non_existent", "deep", "field", "typo")
            assert_false(c2:exists())
            assert_nil(c2:get())
            assert_equal(c2:kind(), "none")

            assert_equal(#doc:mutations(), 0)
            assert_false(doc:changed())
        end)

        it("cursor provides correct normalized path", function()
            local doc = alter.parse(sample_json, FakeBackend)
            local c = doc:at("nested"):at("count")
            local p = c:path()
            assert_equal(#p, 2)
            assert_equal(p[1], "nested")
            assert_equal(p[2], "count")
        end)
    end)

    describe("Mutation Staging, Render & Rollback", function()
        it("staging mutations records mutation IR without altering original text", function()
            local doc = alter.parse(sample_json, FakeBackend)
            doc:at("version"):set(2)
            doc:at("new_key"):set("hello")

            local muts = doc:mutations()
            assert_equal(#muts, 2)
            assert_equal(muts[1].kind, "set")
            assert_equal(muts[1].path[1], "version")
            assert_equal(muts[1].value, 2)

            -- Base state before commit is still unchanged
            assert_equal(doc:value_at("version"), 1)
        end)

        it("render previews mutations idempotently without mutating staging or disk", function()
            local doc = alter.parse(sample_json, FakeBackend)
            doc:at("version"):set(42)

            local text1, res1 = doc:render()
            assert_true(res1.changed)
            assert_match(text1, "42")
            assert_equal(#doc:mutations(), 1) -- Still staged!

            local text2, res2 = doc:render()
            assert_equal(text1, text2)
            assert_equal(#doc:mutations(), 1) -- Idempotent!
        end)

        it("rollback clears staged mutations and reverts changed status", function()
            local doc = alter.parse(sample_json, FakeBackend)
            doc:at("version"):set(99)
            assert_true(doc:changed())
            assert_equal(#doc:mutations(), 1)

            doc:rollback()
            assert_equal(#doc:mutations(), 0)
            assert_false(doc:changed())
            assert_equal(doc:at("version"):get(), 1)
        end)

        it("clear_mutations is alias for rollback", function()
            local doc = alter.parse(sample_json, FakeBackend)
            doc:at("temp"):set("xyz")
            assert_equal(#doc:mutations(), 1)
            doc:clear_mutations()
            assert_equal(#doc:mutations(), 0)
        end)
    end)

    describe("Commit & Atomic File I/O", function()
        it("committing an unmutated document is a no-op", function()
            local doc = alter.parse(sample_json, FakeBackend)
            local res = doc:commit()
            assert_not_nil(res)
            assert_false(res.changed)
            assert_equal(res.bytes_written, 0)
            assert_equal(#res.mutations, 0)
        end)

        it("committing in-memory document applies mutations and clears staging", function()
            local doc = alter.parse(sample_json, FakeBackend)
            doc:at("version"):set(100)
            local res = doc:commit()
            assert_not_nil(res)
            assert_true(res.changed)
            assert_equal(#res.mutations, 1)
            assert_equal(#doc:mutations(), 0)
            assert_equal(doc:at("version"):get(), 100)
            assert_false(doc:changed())
        end)

        it("committing file document writes atomically and persists to disk", function()
            local tmp_path = "/tmp/alter_atomic_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)) .. ".txt"
            local f = io.open(tmp_path, "w")
            assert_not_nil(f)
            f:write('{"initial": 1}')
            f:close()

            local doc, err = alter.open(tmp_path, { backend = FakeBackend })
            assert_nil(err)
            doc:at("initial"):set(2)
            doc:at("added"):set("yes")

            local commit_res = doc:commit()
            assert_true(commit_res.changed)
            assert_true(commit_res.bytes_written > 0)

            -- Read back from disk to verify atomic persistence
            local disk_f = io.open(tmp_path, "r")
            local disk_text = disk_f:read("*a")
            disk_f:close()

            assert_match(disk_text, "added")
            assert_match(disk_text, "yes")

            -- Clean up
            os.remove(tmp_path)
        end)

        it("idempotent commit on already committed document causes no extra writes", function()
            local doc = alter.parse(sample_json, FakeBackend)
            doc:at("version"):set(5)
            local c1 = doc:commit()
            assert_true(c1.changed)

            local c2 = doc:commit()
            assert_false(c2.changed)
            assert_equal(c2.bytes_written, 0)
        end)
    end)
end)
