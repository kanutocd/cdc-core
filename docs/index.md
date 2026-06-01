# CDC Core API Documentation

`cdc-core` provides the small domain vocabulary used by the CDC Ecosystem runtime layer.
It defines immutable, Ractor-safe primitives for describing database changes and for routing those changes through processors and pipelines.

## Where cdc-core Fits

    PostgreSQL WAL
          |
          v
    pgoutput-client
          |
          v
    pgoutput-parser
          |
          v
    pgoutput-decoder
          |
          v
    cdc-core
          |
          v
    processors

`cdc-core` does not connect to PostgreSQL, parse pgoutput messages, decode database values, or manage replication slots.
It provides the runtime-independent objects and contracts used after a change has already been decoded.

## Core Concepts

### ChangeEvent

A `CDC::Core::ChangeEvent` represents one database change.
It records the operation, table identity, old values, new values, primary key, transaction identity, log position, and metadata.

    event = CDC::Core::ChangeEvent.new(
      operation: :update,
      schema: "public",
      table: "users",
      old_values: { "email" => "old@example.com" },
      new_values: { "email" => "new@example.com" },
      primary_key: { "id" => 7 },
      transaction_id: 42,
      commit_lsn: "0/16B6C50"
    )

    event.update?
    event.qualified_table_name
    event.changes

### ColumnChange

A `CDC::Core::ColumnChange` describes a single column-level value transition.
It is useful when processors care about what changed rather than only that a row changed.

    change = CDC::Core::ColumnChange.new(
      name: "email",
      old_value: "old@example.com",
      new_value: "new@example.com"
    )

    change.changed?

### TransactionEnvelope

A `CDC::Core::TransactionEnvelope` groups events that belong to the same database transaction.
Processors can use it when transactional ordering matters.

    envelope = CDC::Core::TransactionEnvelope.new(
      transaction_id: 42,
      commit_lsn: "0/16B6C50",
      events: [event]
    )

    envelope.size
    envelope.empty?

### Processor

A `CDC::Core::Processor` is the base contract for event processors.
Custom processors implement `#call` and return a `CDC::Core::ProcessorResult`.

    class AuditProcessor < CDC::Core::Processor
      def call(event)
        # write audit record here
        success(event)
      end
    end

### Pipeline

A `CDC::Core::Pipeline` applies processors to events.
It keeps orchestration small and explicit while allowing more advanced runtime gems to build on top of it later.

    pipeline = CDC::Core::Pipeline.new(
      processors: [AuditProcessor.new]
    )

    pipeline.call(event)

### Filter

A `CDC::Core::Filter` decides whether an event should continue through a processor or pipeline.
Filters are intentionally small so routing logic remains easy to test.

    filter = CDC::Core::Filter.new do |event|
      event.table == "users"
    end

    filter.call(event)

## Design Principles

`cdc-core` follows the same principles as the wider CDC Ecosystem:

- small public API
- pure Ruby implementation
- immutable, shareable data structures where practical
- no runtime dependencies
- no database-specific transport concerns
- no Rails coupling
- no required concurrency runtime

Concurrency and parallelism belong in specialized runtime gems such as `cdc-ractor` and `cdc-fiber`.
`cdc-core` stays boring on purpose.

## API Reference

Use the class and method navigation in the sidebar for the full API reference.
