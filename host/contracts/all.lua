-- Canonical data-contract definitions. This file intentionally has no Alter
-- runtime imports: it is loaded only by tests, conformance tooling, and LuaLS.
local v = require("valua")

local contracts = {}

local PathSegment = v.union({
    v.string(),
    v.pipe(v.integer(), v.min_value(1)),
})
contracts.PathSegment = PathSegment
---@valua-alias alter.PathSegment PathSegment

local Path = v.array(PathSegment)
contracts.Path = Path
---@valua-alias alter.Path Path

local MutationKind = v.picklist({
    "set", "remove", "ensure", "ensure_object", "ensure_array", "merge", "append", "append_unique",
})
contracts.MutationKind = MutationKind
---@valua-alias alter.MutationKind MutationKind

local Mutation = v.object({
    kind = MutationKind,
    path = Path,
    value = v.optional(v.any()),
    deep = v.optional(v.boolean()),
    key = v.optional(v.string()),
})
contracts.Mutation = Mutation
---@valua-alias alter.Mutation Mutation

local BackendCapabilities = v.object({
    comments = v.boolean(),
    ordering = v.boolean(),
    formatting = v.boolean(),
    duplicate_keys = v.boolean(),
    minimal_edits = v.boolean(),
})
contracts.BackendCapabilities = BackendCapabilities
---@valua-alias alter.BackendCapabilities BackendCapabilities

local Conflict = v.object({
    kind = v.literal("conflict"),
    path = Path,
    expected = v.string(),
    actual = v.string(),
    message = v.string(),
})
contracts.Conflict = Conflict
---@valua-alias alter.Conflict Conflict

local Error = v.object({
    kind = v.string(),
    message = v.string(),
    path = v.optional(Path),
    cause = v.optional(v.any()),
})
contracts.Error = Error
---@valua-alias alter.Error Error

local CommitResult = v.object({
    changed = v.boolean(),
    mutations = v.array(Mutation),
    text = v.string(),
    bytes_written = v.integer(),
})
contracts.CommitResult = CommitResult
---@valua-alias alter.CommitResult CommitResult

local RenderResult = v.object({
    changed = v.boolean(),
    mutations = v.array(Mutation),
    text = v.string(),
})
contracts.RenderResult = RenderResult
---@valua-alias alter.RenderResult RenderResult

local BackendDescriptor = v.object({
    name = v.string(),
    capabilities = BackendCapabilities,
})
contracts.BackendDescriptor = BackendDescriptor
---@valua-alias alter.BackendDescriptor BackendDescriptor

return contracts
