## [Unreleased]

## [0.1.1] - 2026-06-09

### Added

- Added `CDC::Core::OrderingScope`, `OrderingPolicy`, `OrderingKey`, and `EventPosition`.
- Added `CDC::Core::SourceAdapter` as the shared source normalization contract.
- Added `CDC::Core::Router` and `UnsupportedWorkItemError`.
- Added optional lifecycle hooks to `CDC::Core::Processor`.
- Added structured failure metadata to `CDC::Core::ProcessorResult`.
- Added status validation and serializable projection helpers to `CDC::Core::ProcessorResult`.
- Added backend-agnostic observer hooks for instrumentation.
- Added canonical metric names and tag helpers to `CDC::Core::Observer`.

### Fixed

- Preserve explicit `false` metadata values when reading `EventMetadata` by symbol or string key.
- Raise `CDC::Core::InvalidOperationError` for nil operation input instead of leaking `NoMethodError`.
- Align API documentation examples with the current `#process`, `Pipeline.new(processor:)`, and `Filter#match?` contracts.

---

## [0.1.0] - 2026-05-31

### Added

- Added immutable `CDC::Core::ChangeEvent`.
- Added immutable `CDC::Core::ColumnChange`.
- Added immutable `CDC::Core::TransactionEnvelope`.
- Added `CDC::Core::EventMetadata`.
- Added operation validation.
- Added `CDC::Core::Processor` base contract.
- Added `CDC::Core::ProcessorResult`.
- Added `CDC::Core::CompositeProcessor`.
- Added `CDC::Core::Filter`.
- Added `CDC::Core::Pipeline`.
- Added Ractor-safe processor intent declaration via `ractor_safe!`.
- Added RBS signatures.
- Added Minitest coverage.
- Added README and examples.
