---@meta

---The serialisable path used by Alter's mutation protocol. Array indexes are
---one-based, matching Lua arrays.
---@alias alter.PathSegment string|integer
---@alias alter.Path alter.PathSegment[]

---@alias alter.MutationKind
---| '"set"'
---| '"remove"'
---| '"ensure"'
---| '"ensure_object"'
---| '"ensure_array"'
---| '"merge"'
---| '"append"'
---| '"append_unique"'

---@class alter.Mutation
---@field kind alter.MutationKind
---@field path alter.Path
---@field value? any
---@field deep? boolean
---@field key? string

---@class alter.BackendCapabilities
---@field comments boolean
---@field ordering boolean
---@field formatting boolean
---@field duplicate_keys boolean
---@field minimal_edits boolean

---@class alter.BackendDescriptor
---@field name string
---@field capabilities alter.BackendCapabilities

---@class alter.Conflict
---@field kind '"conflict"'
---@field path alter.Path
---@field expected string
---@field actual string
---@field message string

---@class alter.Error
---@field kind string
---@field message string
---@field path? alter.Path
---@field cause? any

---@class alter.CommitResult
---@field changed boolean
---@field mutations alter.Mutation[]
---@field text string
---@field bytes_written integer

---@class alter.RenderResult
---@field changed boolean
---@field mutations alter.Mutation[]
---@field text string

---@class alter.BackendDocument
---@field resolve fun(self: alter.BackendDocument, path: alter.Path): any|nil
---@field kind_at fun(self: alter.BackendDocument, path: alter.Path): string|nil
---@field value_at fun(self: alter.BackendDocument, path: alter.Path): any
---@field apply fun(self: alter.BackendDocument, mutation: alter.Mutation): true|nil, alter.Error|alter.Conflict|nil
---@field render fun(self: alter.BackendDocument): string
---@field clone fun(self: alter.BackendDocument): alter.BackendDocument

---@class alter.Backend: alter.BackendDescriptor
---@field name string
---@field capabilities alter.BackendCapabilities
---@field parse fun(text: string, opts?: table): alter.BackendDocument|nil, alter.Error|nil

---@class alter.FileSystem
---@field write_file_atomic fun(path: string, text: string): boolean|nil, string|nil

---@class alter.ParseOptions
---@field filepath? string
---@field fs? alter.FileSystem

---@class alter.OpenOptions: alter.ParseOptions
---@field backend alter.Backend
---@field create? boolean
---@field default_text? string

---@class alter.Document
---@field at fun(self: alter.Document, ...: alter.PathSegment): alter.Cursor
---@field kind_at fun(self: alter.Document, path: alter.Path): string
---@field value_at fun(self: alter.Document, path: alter.Path): any
---@field stage fun(self: alter.Document, mutation: alter.Mutation): alter.Document
---@field mutations fun(self: alter.Document): alter.Mutation[]
---@field clear_mutations fun(self: alter.Document): alter.Document
---@field rollback fun(self: alter.Document): alter.Document
---@field changed fun(self: alter.Document): boolean
---@field render fun(self: alter.Document): string|nil, alter.RenderResult|alter.Error, alter.BackendDocument|nil
---@field commit fun(self: alter.Document): alter.CommitResult|nil, alter.Error|alter.Conflict|nil

---@class alter.Cursor
---@field at fun(self: alter.Cursor, ...: alter.PathSegment): alter.Cursor
---@field path fun(self: alter.Cursor): alter.Path
---@field doc fun(self: alter.Cursor): alter.Document
---@field exists fun(self: alter.Cursor): boolean
---@field kind fun(self: alter.Cursor): string
---@field get fun(self: alter.Cursor): any
---@field set fun(self: alter.Cursor, value: any): alter.Cursor
---@field remove fun(self: alter.Cursor): alter.Cursor
---@field ensure fun(self: alter.Cursor, value: any): alter.Cursor
---@field ensure_object fun(self: alter.Cursor): alter.Cursor
---@field ensure_array fun(self: alter.Cursor): alter.Cursor
---@field merge fun(self: alter.Cursor, value: table, opts?: { deep?: boolean }): alter.Cursor
---@field append fun(self: alter.Cursor, value: any): alter.Cursor
---@field append_unique fun(self: alter.Cursor, value: any, key?: string): alter.Cursor

---@class alter.Module
---@field _VERSION string
---@field NULL table
---@field parse fun(text: string, backend: alter.Backend, opts?: alter.ParseOptions): alter.Document|nil, alter.Error|nil
---@field create fun(backend: alter.Backend, opts?: alter.ParseOptions): alter.Document|nil, alter.Error|nil
---@field open fun(filepath: string, opts: alter.OpenOptions): alter.Document|nil, alter.Error|nil

return {}
