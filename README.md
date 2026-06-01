# cdc-core

Database-agnostic Change Data Capture domain primitives for Ruby.

`cdc-core` provides immutable, Ractor-safe event objects and processor contracts for building CDC systems. It intentionally does not connect to databases, parse wire protocols, decode PostgreSQL OIDs, or integrate with Rails.

## Requirements

- Ruby 3.4+

## Features

- Immutable `ChangeEvent` objects
- Transaction grouping via `TransactionEnvelope`
- Column-level change objects
- Processor and composite processor contracts
- Event filters
- Small pipeline orchestration object
- Ractor-safe event and transaction objects
- RBS signatures
- YARD-compatible documentation
- No runtime dependencies

## Ecosystem Position

```text
pgoutput-client
      │
      ▼
pgoutput-parser
      │
      ▼
pgoutput-decoder
      │
      ▼
cdc-core
      │
      ▼
whodunit-chronicles
```

`cdc-core` is the shared vocabulary layer. It defines what a change event, transaction, processor, and pipeline result means without caring where the event came from.

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

A transaction envelope is the natural unit for future parallel processing because it preserves database transaction boundaries.

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

This declares intent only. `cdc-core` does not execute processors in Ractors. A future runtime gem can use this signal.

## Composite Processor

```ruby
processor = CDC::Core::CompositeProcessor.new([
  AuditProcessor.new,
  AnalyticsProcessor.new
])

results = processor.process(event)
```

## Filters and Pipeline

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

## Non-goals

`cdc-core` does not:

- Connect to PostgreSQL
- Parse `pgoutput`
- Decode PostgreSQL values
- Manage replication slots
- Run Ractor pools
- Persist audit records
- Integrate with ActiveRecord
- Publish to Kafka, Redis, or HTTP sinks

## Development

```bash
bundle exec rake
bundle exec steep check
```

## License

MIT.
