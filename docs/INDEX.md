# CDC Core API Documentation

`cdc-core` is the shared vocabulary of the CDC Ecosystem.

It defines immutable, Ractor-safe primitives for describing data changes and the small contracts used to route those changes through processors and pipelines. It does not ingest from upstream systems, decode source-specific payloads, choose a scheduler, or persist to sinks.

See [architecture.md](architecture.md) for the arc42-style component overview.

## Where cdc-core Fits

```text
upstream source
      |
      v
source adapter
      |
      v
cdc-core vocabulary
      |
      +--> cdc-parallel       CPU-bound processing
      |
      +--> cdc-concurrent     I/O-bound processing
      |
      +--> application sinks / processors
```
The important boundary is the normalization boundary defined by CDC::Core::SourceAdapter.

A source adapter turns a source-specific stream, log, API payload, or protocol message into `cdc-core` objects. After that normalization step, downstream processors can use one shared language regardless of where the change came from.

## What cdc-core Owns

`cdc-core` owns the shared vocabulary and contracts:

- `CDC::Core::SourceAdapter`
- `CDC::Core::ChangeEvent`
- `CDC::Core::ColumnChange`
- `CDC::Core::TransactionEnvelope`
- `CDC::Core::OrderingPolicy`
- `CDC::Core::OrderingKey`
- `CDC::Core::EventPosition`
- `CDC::Core::Processor`
- `CDC::Core::ProcessorResult`
- `CDC::Core::Router`
- `CDC::Core::Pipeline`
- `CDC::Core::Filter`
- `CDC::Core::Observer`

`cdc-core` does not connect to PostgreSQL, parse `pgoutput`, decode PostgreSQL values, manage replication slots, run Ractor pools, run fiber schedulers, or write sink data.

## SourceAdapter

CDC::Core::SourceAdapter defines the normalization contract between
source-specific payloads and the cdc-core vocabulary.

Concrete implementations may be provided by optional ecosystem gems.

## Source Adapters

Source adapters are the missing bridge between upstream systems and the shared CDC vocabulary.

They are responsible for normalizing source-specific payloads into:

- `CDC::Core::ChangeEvent`
- `CDC::Core::TransactionEnvelope`
- batches of core work items

A source adapter may be log-based, protocol-based, API-based, database-specific, or application-specific.

```text
PostgreSQL WAL / pgoutput    -> PostgreSQL source adapter -> cdc-core
Rails production log         -> Rails log source adapter   -> cdc-core
Nginx access log             -> Nginx log source adapter   -> cdc-core
Webhook/API payload          -> API source adapter         -> cdc-core
```

The current PostgreSQL path is represented by the `pgoutput*` family:

```text
pgoutput-client -> pgoutput-parser -> pgoutput-decoder -> source adapter -> cdc-core
```

That adapter boundary is intentionally separate from `cdc-core`. `cdc-core` defines the vocabulary; the source adapter performs the translation.

Example shape:

```ruby
adapter = DemoSourceAdapter.new

work_item = adapter.normalize(payload)
work_items = adapter.normalize_many(payloads)
```

## Downstream Runtime Boundaries

`cdc-parallel` and `cdc-concurrent` are downstream consumers of `cdc-core` change events.

They do not define the CDC vocabulary. They decide how already-normalized work should execute.

```text
cdc-core
   |
   +--> cdc-parallel
   |       heavy CPU-bound processing
   |       Ractor-oriented parallel execution
   |
   +--> cdc-concurrent
           I/O-heavy processing
           fiber-friendly concurrent execution
```

Use `cdc-core` directly when a single-process, synchronous processor is enough.
Use `cdc-parallel` when CPU-bound processors need parallel execution.
Use `cdc-concurrent` when processors spend most of their time waiting on I/O such as HTTP, Redis, object storage, external APIs, or database writes.

## Core Concepts

### ChangeEvent

A `CDC::Core::ChangeEvent` represents one logical data change.
It records the operation, table identity, old values, new values, primary key, transaction identity, log position, and metadata.

```ruby
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
```

### ColumnChange

A `CDC::Core::ColumnChange` describes a single column-level value transition.
It is useful when processors care about what changed rather than only that a row changed.

```ruby
change = CDC::Core::ColumnChange.new(
  name: "email",
  old_value: "old@example.com",
  new_value: "new@example.com"
)

change.changed?
```

### TransactionEnvelope

A `CDC::Core::TransactionEnvelope` groups events that belong to the same database transaction.
Processors can use it when transactional ordering matters.

```ruby
envelope = CDC::Core::TransactionEnvelope.new(
  transaction_id: 42,
  commit_lsn: "0/16B6C50",
  events: [event]
)

envelope.size
envelope.empty?
```

### Router

`CDC::Core::Router` dispatches supported CDC work items to the appropriate handler.

```ruby
router = CDC::Core::Router.new(
  processor: AuditProcessor.new,
  transaction_processor: TransactionAuditProcessor.new
)

router.process(event)
router.process(envelope)
router.process([event, event])
```

### Processor Lifecycle

`CDC::Core::Processor` provides optional lifecycle hooks for runtime layers.

```ruby
processor = AuditProcessor.new

processor.start
processor.flush
processor.stop
processor.healthy?
```

### Failure Metadata

`CDC::Core::ProcessorResult.failure` carries structured failure metadata.

```ruby
result = CDC::Core::ProcessorResult.failure(
  error,
  processor: "AuditProcessor",
  retryable: false,
  reason: "invalid payload"
)

result.failure_reason
result.retryable?
result.processor_name
result.failed_at
result.to_h
```

### Observability

`CDC::Core::Observer` receives dispatch lifecycle notifications from core runtime objects.

```ruby
pipeline = CDC::Core::Pipeline.new(
  processor: AuditProcessor.new,
  observer: MyObserver.new
)

router = CDC::Core::Router.new(
  processor: AuditProcessor.new,
  observer: MyObserver.new
)
```

Core metric names:

```text
cdc_core.dispatch.started
cdc_core.dispatch.succeeded
cdc_core.dispatch.failed
cdc_core.dispatch.skipped
```

Core metric tags are derived from the payload shape and stay backend-agnostic.

### OrderingPolicy, OrderingKey, and EventPosition

`CDC::Core::OrderingPolicy` defines the core ordering contract. It maps a `ChangeEvent` to an ordering key and event position without taking responsibility for scheduling or buffering.

```ruby
policy = CDC::Core::OrderingPolicy.new(scope: :primary_key, position: :commit_lsn)
key = policy.key_for(event)
position = policy.position_for(event)

key.scope
key.components
position.strategy
position.value
```

### Processor

A `CDC::Core::Processor` is the base contract for event processors.
Custom processors implement `#process` and return a `CDC::Core::ProcessorResult`.

```ruby
class AuditProcessor < CDC::Core::Processor
  def process(event)
    # write audit record here
    CDC::Core::ProcessorResult.success(event)
  end
end
```

### Pipeline

A `CDC::Core::Pipeline` applies processors to events.
It keeps orchestration small and explicit while allowing more advanced runtime gems to build on top of it later.

```ruby
pipeline = CDC::Core::Pipeline.new(
  processor: AuditProcessor.new
)

pipeline.process(event)
```

### Filter

A `CDC::Core::Filter` decides whether an event should continue through a processor or pipeline.
Filters are intentionally small so routing logic remains easy to test.

```ruby
filter = CDC::Core::Filter.new do |event|
  event.table == "users"
end

filter.match?(event)
```

## Design Principles

`cdc-core` follows the same principles as the wider CDC Ecosystem:

- small public API
- pure Ruby implementation
- immutable, shareable data structures where practical
- shared vocabulary before runtime mechanism
- no runtime dependencies
- no database-specific transport concerns
- no Rails coupling
- no required concurrency or parallelism runtime

Concurrency and parallelism belong in specialized downstream runtime gems such as `cdc-concurrent` and `cdc-parallel`.

Source ingestion and source-specific normalization belong in source adapters.

`cdc-core` stays boring on purpose.

## API Reference

Use the class and method navigation in the sidebar for the full API reference.
