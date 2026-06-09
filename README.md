# cdc-core

Shared Change Data Capture vocabulary for Ruby.

`cdc-core` provides immutable, Ractor-safe event objects and processor contracts for building CDC systems. It intentionally does not connect to databases, parse wire protocols, decode PostgreSQL OIDs, run schedulers, or integrate with Rails.

## Requirements

- Ruby 3.4+

## Features

- SourceAdapter normalization contract
- Immutable `ChangeEvent` objects
- Transaction grouping via `TransactionEnvelope`
- Column-level change objects
- Ordering vocabulary
- Processor, composite processor, processor chain, and pipeline contracts
- Event filters
- Small pipeline orchestration object
- Router for supported work item shapes
- Observer hooks and canonical metric names
- Ractor-safe event and transaction objects
- RBS signatures
- YARD-compatible documentation
- No runtime dependencies

## Ecosystem Position

```text
upstream source
      |
      v
source adapter
      |
      v
cdc-core
      |
      +--> cdc-parallel       CPU-bound processing
      |
      +--> cdc-concurrent     I/O-bound processing
      |
      +--> application sinks / processors
```

`cdc-core` is the shared vocabulary layer. It defines what a change event, transaction, processor, ordering policy, observer notification, and processor result mean without caring where the event came from or how it will be executed.

## Boundary Summary

`cdc-core` is for vocabulary.

Runtime gems are for execution.

Sinks are for persistence or side effects.

```text
source adapter -> cdc-core vocabulary -> runtime gem -> sink
```

## Source Adapters

CDC::Core::SourceAdapter defines the normalization contract used to translate source-specific payloads into cdc-core vocabulary objects.

It translates source-specific payloads into:

- `CDC::Core::ChangeEvent`
- `CDC::Core::TransactionEnvelope`
- batches of core work items

The current PostgreSQL-oriented path is:

```text
pgoutput-client -> pgoutput-parser -> pgoutput-decoder -> source adapter -> cdc-core
```

The `pgoutput*` family handles PostgreSQL transport, protocol parsing, and type decoding. The source-adapter boundary is where those source-specific details become generic `cdc-core` objects.

Other adapters can normalize logs, API payloads, application events, or other database streams into the same vocabulary.

## Downstream Runtime Gems

`cdc-parallel` and `cdc-concurrent` are downstream consumers of `cdc-core` events.

### cdc-parallel

Use `cdc-parallel` for heavy CPU-bound processing.

Examples:

- transformations
- enrichment
- encoding
- compression
- scoring
- in-memory calculations

It is the Ractor-oriented runtime path.

### cdc-concurrent

Use `cdc-concurrent` for I/O-heavy processing.

Examples:

- HTTP calls
- webhook delivery
- Redis writes
- search indexing
- object storage writes
- database sink writes

It is the fiber-friendly runtime path.

## Installation

```ruby
gem "cdc-core"
```

```ruby
require "cdc/core"
```

## Change Events

```ruby
event = CDC::Core::ChangeEvent.new(
  operation: :update,
  schema: "public",
  table: "users",
  old_values: { "email" => "old@example.com" },
  new_values: { "email" => "new@example.com" },
  primary_key: { "id" => 7 },
  transaction_id: 789,
  commit_lsn: "0/16B6C50"
)

event.update?
# => true

event.qualified_table_name
# => "public.users"

event.changes.map(&:name)
# => ["email"]
```

## Transactions

```ruby
transaction = CDC::Core::TransactionEnvelope.new(
  transaction_id: 789,
  events: [event],
  commit_lsn: "0/16B6C50",
  committed_at: Time.now.utc
)
```

A transaction envelope preserves database transaction boundaries. Runtime gems may use that boundary when they need ordering, batching, or parallel execution decisions.

## Processors

```ruby
class AuditProcessor < CDC::Core::Processor
  def process(event)
    puts event.to_h
    CDC::Core::ProcessorResult.success(event)
  end
end
```

## Ractor-safe processor intent

```ruby
class AnalyticsProcessor < CDC::Core::Processor
  ractor_safe!

  def process(event)
    CDC::Core::ProcessorResult.success(event)
  end
end

AnalyticsProcessor.new.ractor_safe?
# => true
```

This declares intent only. `cdc-core` does not execute processors in Ractors. `cdc-parallel` can use this signal before moving processor work across Ractors.

## Downstream Workflow Primitives

`cdc-core` defines three small workflow primitives. Runtime gems and
application-specific integrations can execute these primitives without
inventing their own composition vocabulary.

### CompositeProcessor

Use `CompositeProcessor` when many independent processors should receive the
same input.

```text
event
  ├─ AuditProcessor
  ├─ AnalyticsProcessor
  └─ WebhookProcessor
```

```ruby
processor = CDC::Core::CompositeProcessor.new([
  AuditProcessor.new,
  AnalyticsProcessor.new
])

results = processor.process(event)
```

### Pipeline

Use `Pipeline` when one processor should run only after filters match.

```text
event
  ↓
filters
  ↓
processor
```

```ruby
pipeline = CDC::Core::Pipeline.new(
  processor: AuditProcessor.new,
  filters: [
    CDC::Core::Filter.schema("public"),
    CDC::Core::Filter.table("users")
  ]
)

result = pipeline.process(event)
```

### ProcessorChain

Use `ProcessorChain` when each processor depends on the previous processor's
successful value.

```text
user_ids
  ↓
LoadUsersProcessor
  ↓
users
  ↓
SendNotificationsProcessor
```

```ruby
class LoadUsersProcessor < CDC::Core::Processor
  def process(user_ids)
    users = User.where(id: user_ids).to_a
    CDC::Core::ProcessorResult.success(user_ids, value: users)
  end
end

class SendNotificationsProcessor < CDC::Core::Processor
  def process(users)
    users.each { |user| NotificationMailer.notice(user).deliver_later }
    CDC::Core::ProcessorResult.success(users, value: users.size)
  end
end

chain = CDC::Core::ProcessorChain.new([
  LoadUsersProcessor.new,
  SendNotificationsProcessor.new
])

result = chain.process([1, 2, 3])
result.value
# => 3
```

## Non-goals

`cdc-core` does not:

- Connect to PostgreSQL
- Parse `pgoutput`
- Decode PostgreSQL values
- Manage replication slots
- Implement concrete source adapters
- Run Ractor pools
- Run fiber schedulers
- Persist audit records
- Integrate with ActiveRecord
- Publish to Kafka, Redis, HTTP, or other sinks

## Documentation

The YARD documentation uses `docs/index.md` as its readme and includes the Markdown files under `docs/`.

```text
--title "cdc-core API Documentation"
--readme docs/index.md
--markup markdown
--output-dir doc
lib/**/*.rb
-
docs/**/*.md
```

## Development

```bash
bundle exec rake
bundle exec steep check
```

## License

[MIT](./LICENSE.txt).
