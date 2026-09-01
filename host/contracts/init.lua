local path_contract = require("contracts.path")
local mutation_contract = require("contracts.mutation")
local capabilities_contract = require("contracts.capabilities")
local errors_contract = require("contracts.errors")
local commit_result_contract = require("contracts.commit_result")
local backend_protocol_contract = require("contracts.backend_protocol")

return {
    PathSegment = path_contract.PathSegment,
    Path = path_contract.Path,
    MutationKind = mutation_contract.MutationKind,
    Mutation = mutation_contract.Mutation,
    BackendCapabilities = capabilities_contract.BackendCapabilities,
    Conflict = errors_contract.Conflict,
    Error = errors_contract.Error,
    CommitResult = commit_result_contract.CommitResult,
    RenderResult = commit_result_contract.RenderResult,
    BackendDescriptor = backend_protocol_contract.BackendDescriptor,
}
