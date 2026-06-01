# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Placeholder for future development.

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
