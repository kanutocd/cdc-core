# CDC Core Architecture

`cdc-core` is the shared vocabulary layer of the CDC ecosystem.

It defines the domain language used by source adapters, runtime gems, processors, and sinks. It does not ingest upstream data, decode source-specific payloads, schedule work, or persist results.

This document is intentionally arc42-shaped, with C4-style zoom levels inside the component view so readers can move from the whole system to the core contracts without losing the thread.

## 1. Introduction and Goals

### Purpose

Explain how `cdc-core` fits into the ecosystem and why its API surface is intentionally small.

The clearest boundary is:

```text
source adapters normalize upstream changes
cdc-core names the shared vocabulary
runtime gems execute normalized work
sinks persist or publish outcomes
```

### Quality Goals

1. Simplicity
2. Reliability
3. Operability
4. Performance
5. Extensibility

### Core Scope

`cdc-core` owns:

- source adapter contract
- change event vocabulary
- transaction envelopes
- ordering vocabulary
- routing vocabulary
- processor lifecycle hooks
- processor results and failure metadata
- observer and metric hooks

`cdc-core` does not own:

- upstream log ingestion
- concrete source adapters
- PostgreSQL connectivity
- `pgoutput` parsing
- PostgreSQL type decoding
- replication slot management
- Ractor pools or other schedulers
- fiber schedulers or async I/O orchestration
- sink persistence

### Why Log-Based CDC First

```text
source log / WAL / append-only stream
            |
            v
       source adapter
            |
            v
    normalize into cdc-core
            |
            v
 shared ordering / routing / results
            |
            v
     runtime execution / sinks
```

The ecosystem starts with log-based CDC because it exercises the hard parts of the problem at the source boundary: stable ordering, transaction grouping, replayable positions, and incremental change capture without full reloads.

PostgreSQL WAL is the first concrete upstream because it is a strong reference implementation of that model. It gives the ecosystem a real, durable stream to normalize before other adapters map their own source vocabulary into the same shared surface.

Other sources can still fit the model later, but they should do so by normalizing into `cdc-core` rather than by redefining the shared vocabulary.

## 2. Context and Scope

### System Context

```text
Upstream source
    |
    +--> PostgreSQL WAL
    |       |
    |       v
    |   pgoutput-client
    |       |
    |       v
    |   pgoutput-parser
    |       |
    |       v
    |   pgoutput-decoder
    |       |
    |       v
    |   PostgreSQL source adapter
    |
    +--> Rails production log
    |       |
    |       v
    |   Rails log source adapter
    |
    +--> Nginx access log
    |       |
    |       v
    |   Nginx log source adapter
    |
    +--> Other source adapters
            |
            v
         cdc-core
            |
            +--> cdc-parallel
            |
            +--> cdc-concurrent
            |
            +--> application processors / sinks
```

### Responsibilities by Layer

```text
source -> source adapter -> shared vocabulary -> runtime gems -> sinks
```

- Source systems produce source-specific changes.
- Source adapters normalize those changes into `cdc-core` vocabulary.
- `pgoutput-client` streams PostgreSQL replication data.
- `pgoutput-parser` parses protocol payloads.
- `pgoutput-decoder` converts protocol messages into typed row changes.
- The concrete PostgreSQL source-adapter path currently lives around the `pgoutput*` family; `cdc-core` defines the boundary, not the execution model.
- Non-PostgreSQL adapters can feed the same shared vocabulary when they emit compatible change semantics.
- `cdc-core` defines the shared language and contracts.
- `cdc-parallel` consumes normalized change events for CPU-bound work with Ractors.
- `cdc-concurrent` consumes normalized change events for I/O-heavy work with fiber-friendly concurrency.
- Application processors and sinks perform business-specific effects.

## 3. Solution Strategy

### Shared Vocabulary First

Other components should describe their behavior using `cdc-core` types instead of introducing local equivalents.

### Source Adapter Boundary

Source-specific concerns belong before `cdc-core`.

A source adapter may know about WAL, API payloads, log formats, HTTP headers, relation metadata, OIDs, or custom source positions. It must translate those details into core terms before handing work to downstream runtimes.

### Contract Over Mechanism

`cdc-core` defines what a change, transaction, order, result, or observer notification means. Runtime gems decide how to schedule and execute work.

### Runtime Specialization Downstream

`cdc-parallel` and `cdc-concurrent` are downstream consumers of normalized `cdc-core` work items.

```text
cdc-core
   |
   +--> cdc-parallel       heavy CPU-bound processing
   |
   +--> cdc-concurrent     I/O-heavy processing
```

`cdc-parallel` is the Ractor-oriented path for CPU-bound processors.
`cdc-concurrent` is the fiber-friendly path for processors that spend most of their time waiting on I/O.

### Optional Everything Beyond the Vocabulary

Source adapters, runtime acceleration, metrics backends, and sink storage remain optional. The core stays small so it can be reused everywhere.

## 4. Building Block View

### Zoom 1: Ecosystem Shape

```text
            +-------------------+
            |  Upstream source  |
            +-------------------+
                 /    |    \
                v     v     v
         +-----------+ +-----------+ +-----------+
         | pgoutput* | | Rails log | | Nginx log |
         +-----------+ +-----------+ +-----------+
                |       |       |
                v       v       v
         +-----------+ +-----------+ +-----------+
         |PostgreSQL | | Rails log | | Nginx log |
         |  adapter  | |  adapter  | |  adapter  |
         +-----------+ +-----------+ +-----------+
                \       |       /
                 \      |      /
                  v     v     v
                +-----------------+
                |    cdc-core     |
                +-----------------+
                 /       |       \
                v        v        v
       +--------------+ +------+ +----------------+
       | cdc-parallel | | sink | | cdc-concurrent |
       +--------------+ +------+ +----------------+
```

### Zoom 2: `cdc-core` Container View

```text
ChangeEvent
ColumnChange
TransactionEnvelope
OrderingPolicy
OrderingKey
EventPosition
Router
Processor
Pipeline
CompositeProcessor
ProcessorChain
ProcessorResult
Filter
Observer
```

### Zoom 3: Core Component View

```text
ChangeEvent
   |-- operation, schema, table, values, primary key
   |-- transaction id, commit LSN, sequence number
   |-- metadata

TransactionEnvelope
   |-- transaction_id
   |-- events[]
   |-- commit_lsn / committed_at

OrderingPolicy
   |-- scope
   |-- position
   |-- transaction awareness

Router
   |-- ChangeEvent
   |-- TransactionEnvelope
   |-- batches

ProcessorResult
   |-- success / skipped / failure
   |-- value payload for chained processors
   |-- structured failure metadata
   |-- shareable projection

Pipeline
   |-- filters[]
   |-- one processor
   |-- skip when a filter does not match

CompositeProcessor
   |-- processors[]
   |-- same input fan-out
   |-- aggregate processor results

ProcessorChain
   |-- processors[]
   |-- output of step N feeds step N+1
   |-- stop on failure or skipped result

Filter
   |-- match?
   |-- block or subclass predicate

Observer
   |-- lifecycle notifications
   |-- metric names
   |-- metric tags
```

### Zoom 3a: Normalization Surface

```text
source-specific term       -> cdc-core term
---------------------------------------------
row identifier             -> primary_key
stream or transaction id   -> transaction_id
source position marker     -> commit_lsn or position metadata
entity or grouping name    -> schema / table / metadata
source-specific operation  -> operation
source-specific values     -> old_values / new_values
source-specific extra data -> metadata
```

The names on the right are the canonical surface used by the current CDC model. The source adapter is responsible for mapping its own vocabulary into that surface before handing data to runtime gems.

## 5. Runtime View

### Single Event

```text
source adapter
    -> ChangeEvent
    -> Filter
    -> Processor / Pipeline / CompositeProcessor / ProcessorChain
    -> ProcessorResult
    -> Observer
```

### Transaction

```text
source adapter
    -> TransactionEnvelope
    -> Router
    -> transaction processor/runtime
    -> results
    -> Observer
```

### Batch

```text
source adapter
    -> [ChangeEvent, ChangeEvent, ...]
    -> Router / CompositeProcessor / runtime gem
    -> ordered results
    -> structured failures when needed
```

### Workflow Primitives

`cdc-core` exposes three small processor composition shapes. They are intentionally distinct so downstream runtimes and application code can reason about dependencies clearly.

```text
Pipeline
    filters + one processor

CompositeProcessor
    one input -> many processors

ProcessorChain
    processor A result -> processor B input
```

#### Pipeline: filters plus one processor

Use `Pipeline` when a work item should pass through one or more filters before a single processor runs.

```text
ChangeEvent
    -> Filter[]
    -> Processor
    -> ProcessorResult
```

A pipeline is useful for table-specific, operation-specific, tenant-specific, or metadata-specific processing where skipped events should be represented as normalized `ProcessorResult` values.

#### CompositeProcessor: same input fan-out

Use `CompositeProcessor` when multiple independent processors should receive the same input.

```text
ChangeEvent
    +-> AuditProcessor
    +-> MetricsProcessor
    +-> SearchProcessor
```

A composite is useful when processors do not depend on each other's output. Because each processor receives the same work item, downstream runtimes can later decide whether to execute the fan-out sequentially, concurrently, or in parallel.

#### ProcessorChain: result-fed sequential workflow

Use `ProcessorChain` when each step depends on the previous step's successful value.

```text
input
    -> Processor A
    -> ProcessorResult.value
    -> Processor B
    -> ProcessorResult.value
    -> Processor C
```

A chain is useful for staged workflows such as load records, transform records, then deliver side effects. It should stop on failure or skipped results so dependent processors do not receive invalid input.

### How the Workflow Primitives Compose

A downstream runtime or application can compose the primitives without changing the processor contract.

```text
ChangeEvent
    |
    v
Pipeline
    |-- Filter: only users table
    |-- Filter: only update operations
    |
    v
ProcessorChain
    |
    +--> LoadAffectedUsersProcessor
    |       input: ChangeEvent
    |       value: users[]
    |
    +--> CompositeProcessor
            input: users[]
            +--> SendNotificationsProcessor
            +--> UpdateSearchIndexProcessor
            +--> EmitMetricsProcessor
```

In this shape:

- `Pipeline` decides whether the event should be processed.
- `ProcessorChain` models dependency between workflow stages.
- `CompositeProcessor` fans out independent side effects that share the same intermediate value.
- Every stage still returns a `ProcessorResult`.

### CPU-Bound Runtime Path

```text
ChangeEvent / TransactionEnvelope
        |
        v
cdc-parallel
        |
        v
Ractor-oriented processor execution
```

Use this when work is dominated by CPU: transformations, calculations, compression, encoding, enrichment, parsing, scoring, or heavy in-memory processing.

### I/O-Bound Runtime Path

```text
ChangeEvent / TransactionEnvelope
        |
        v
cdc-concurrent
        |
        v
fiber-friendly processor execution
```

Use this when work is dominated by waiting: HTTP APIs, Redis, object storage, database writes, search indexing, webhooks, or other network calls.

## 6. Crosscutting Concepts

### Ordering

Supported scopes:

- `:global`
- `:transaction`
- `:relation`
- `:primary_key`
- `:none`

The point of `OrderingPolicy` is to name the contract, not to schedule work.

### Observability

`Observer` defines:

- canonical metric names
- canonical metric tags
- lifecycle notifications

### Failure Semantics

`ProcessorResult` carries:

- status
- event
- error
- failure reason
- retryability
- processor name
- failure timestamp

### Ractor Safety

The core data model is designed to be immutable and shareable where practical so runtime gems can move it safely across Ractors.

### Fiber Friendliness

The core data model does not assume a blocking or non-blocking execution model. Fiber scheduling belongs to `cdc-concurrent`, not `cdc-core`.

## 7. Design Decisions

```text
Ruby 3.4+ for shared foundation gems
Pure Ruby first
No required runtime dependencies
Source adapters outside cdc-core
Runtime acceleration outside cdc-core
```

## 8. Deployment View

`cdc-core` is deployed as a Ruby library, not as a service. Typical deployment shapes look like this:

### Library in an Application

```text
Rails / Sinatra / Hanami / Custom App
    |
    +--> source adapter
    +--> cdc-core
    +--> optional cdc-parallel or cdc-concurrent
    +--> sink / projection code
```

### Runtime Process

```text
Upstream source(s)
   |
   +--> PostgreSQL / Rails log / Nginx log / etc.
             |
             v
      source adapter process
             |
             +--> parser / decoder when needed
             +--> cdc-core vocabulary
             +--> optional runtime acceleration
             +--> observer / metrics backend
             +--> application sink or processor
```

### Typical Responsibility Split At Runtime

```text
process 1: transport, parsing, decoding, source normalization
process 2: CDC vocabulary, routing, runtime execution
process 3: sink persistence / downstream side effects
```

The exact process layout depends on the source adapter, runtime gem, and deployment topology. `cdc-core` remains the shared contract layer in every case.

## 9. Risks and Technical Debt

- The router and observer surfaces are intentionally minimal, so runtime gems still need to define execution policy.
- Metrics are intentionally backend-agnostic, so downstream users must choose a metrics system.
- Any retry/checkpoint/replay semantics beyond the current `ProcessorResult` shape belong in runtime gems, source adapters, or sinks.

## 10. Glossary

- `Source adapter`: a component that normalizes source-specific changes into `cdc-core` work items
- `ChangeEvent`: one logical data change
- `TransactionEnvelope`: a transaction-sized bundle of events
- `OrderingPolicy`: the ordering vocabulary
- `Router`: a dispatcher for supported work item shapes
- `Pipeline`: filters plus one processor
- `CompositeProcessor`: fan-out composition where many processors receive the same input
- `ProcessorChain`: sequential composition where one processor's successful value feeds the next processor
- `ProcessorResult`: the normalized outcome of processor execution
- `Observer`: the instrumentation hook surface
- `cdc-parallel`: downstream runtime for heavy CPU-bound processing
- `cdc-concurrent`: downstream runtime for I/O-heavy processing
