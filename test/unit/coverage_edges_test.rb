# frozen_string_literal: true

require 'test_helper'
require 'cdc_core'

# rubocop:disable Metrics/ClassLength
class CoverageEdgesTest < Minitest::Test
  class RecordingObserver < CDC::Core::Observer
    attr_reader :started, :succeeded, :failed, :skipped

    def initialize
      super
      @started = []
      @succeeded = []
      @failed = []
      @skipped = []
    end

    def dispatch_started(event) = started << event
    def dispatch_succeeded(result) = succeeded << result
    def dispatch_failed(result) = failed << result
    def dispatch_skipped(result) = skipped << result
  end

  class EventProcessor < CDC::Core::Processor
    def process(event) = CDC::Core::ProcessorResult.success(event)
  end

  class SkippedProcessor < CDC::Core::Processor
    def process(event) = CDC::Core::ProcessorResult.skipped(event)
  end

  class FailureResultProcessor < CDC::Core::Processor
    def process(event) = CDC::Core::ProcessorResult.failure(RuntimeError.new('failed'), event: event)
  end

  class PlainProcessor < CDC::Core::Processor
    def process(event) = CDC::Core::ProcessorResult.success(event)
  end

  def event(transaction_id: 42)
    CDC::Core::ChangeEvent.new(
      operation: :update,
      schema: 'public',
      table: 'users',
      primary_key: { id: 7 },
      transaction_id: transaction_id,
      commit_lsn: '0/16B6C50',
      sequence_number: 3,
      occurred_at: Time.utc(2026, 6, 6, 10, 11, 12)
    )
  end

  def test_event_metadata_falls_back_to_raw_key_when_string_key_is_absent
    key = Object.new
    metadata = CDC::Core::EventMetadata.new(key => 'raw')

    assert_equal 'raw', metadata[key]
    assert_nil metadata[:missing]
  end

  def test_ordering_scope_rejects_and_checks_non_symbolizable_values
    invalid = Object.new

    normalize_error = assert_raises(CDC::Core::InvalidOrderingScopeError) do
      CDC::Core::OrderingScope.normalize(invalid)
    end

    assert_match(/unsupported CDC ordering scope/, normalize_error.message)
    refute CDC::Core::OrderingScope.supported?(invalid)
  end

  def test_ordering_scope_supported_accepts_string_values
    assert CDC::Core::OrderingScope.supported?('relation')
  end

  def test_ordering_policy_rejects_non_symbolizable_position
    invalid = Object.new

    error = assert_raises(CDC::Core::InvalidOrderingPositionError) do
      CDC::Core::OrderingPolicy.new(scope: :global, position: invalid)
    end

    assert_match(/unsupported CDC ordering position/, error.message)
  end

  def test_ordering_policy_serializes_to_shareable_hash
    policy = CDC::Core::OrderingPolicy.new(scope: 'relation', position: 'occurred_at', transaction_aware: false)
    hash = policy.to_h

    assert_equal :relation, hash['scope']
    assert_equal :occurred_at, hash['position']
    refute hash['transaction_aware']
    assert Ractor.shareable?(hash)
  end

  def test_ordering_policy_transaction_key_uses_transaction_id
    key = CDC::Core::OrderingPolicy.new(scope: :transaction).key_for(event)

    assert_equal :transaction, key.scope
    assert_equal 42, key.components['transaction_id']
  end

  def test_ordering_policy_relation_key_uses_schema_and_table
    key = CDC::Core::OrderingPolicy.new(scope: :relation).key_for(event)

    assert_equal 'public', key.components['schema']
    assert_equal 'users', key.components['table']
    refute key.components.key?('primary_key')
  end

  def test_event_position_and_ordering_key_to_h_are_shareable
    position = CDC::Core::EventPosition.new(strategy: :commit_lsn, value: '0/16B6C50')
    key = CDC::Core::OrderingKey.new(scope: :relation, components: { schema: 'public', table: 'users' })

    assert_equal :commit_lsn, position.to_h['strategy']
    assert_equal :relation, key.to_h['scope']
    assert Ractor.shareable?(position.to_h)
    assert Ractor.shareable?(key.to_h)
  end

  def test_processor_result_rejects_non_symbolizable_status
    error = assert_raises(ArgumentError) { CDC::Core::ProcessorResult.new(Object.new) }

    assert_match(/unsupported processor result status/, error.message)
  end

  def test_processor_result_to_h_handles_nil_event
    hash = CDC::Core::ProcessorResult.success.to_h

    assert_equal :success, hash['status']
    assert_empty hash['event'], 'NilClass#to_h implentation is an empty Hash'
  end

  def test_observer_metric_tags_for_unknown_payload_and_result_without_optional_tags
    unknown_tags = CDC::Core::Observer.metric_tags(:symbol_payload)
    success_tags = CDC::Core::Observer.metric_tags(CDC::Core::ProcessorResult.success(event))

    assert_equal 'Symbol', unknown_tags['kind']
    assert_equal 'processor_result', success_tags['kind']
    refute success_tags.key?('processor')
    refute success_tags.key?('failure_reason')
  end

  def test_observer_metric_tags_for_change_event_without_transaction_id
    tags = CDC::Core::Observer.metric_tags(event(transaction_id: nil))

    assert_equal 'change_event', tags['kind']
    refute tags.key?('transaction_id')
  end

  def test_router_raises_for_transaction_without_transaction_processor
    router = CDC::Core::Router.new(processor: EventProcessor.new)
    transaction = CDC::Core::TransactionEnvelope.new(transaction_id: 7, events: [event])

    error = assert_raises(CDC::Core::UnsupportedWorkItemError) { router.process(transaction) }

    assert_match(/transaction processor not configured/, error.message)
  end

  def test_router_raises_for_mixed_arrays
    router = CDC::Core::Router.new(processor: EventProcessor.new)

    error = assert_raises(CDC::Core::UnsupportedWorkItemError) { router.process([Object.new, event]) }

    assert_match(/Array\(Object\)/, error.message)
  end

  def test_router_falls_back_to_per_event_processing_for_arrays
    router = CDC::Core::Router.new(processor: PlainProcessor.new)
    results = router.process([event, event])

    assert_equal 2, results.size
    assert results.all?(&:success?)
    assert Ractor.shareable?(results)
  end

  # rubocop:disable Metrics/AbcSize
  def test_router_observes_success_failure_and_skipped_processor_results
    success_observer = RecordingObserver.new
    CDC::Core::Router.new(processor: EventProcessor.new, observer: success_observer).process(event)

    failure_observer = RecordingObserver.new
    CDC::Core::Router.new(processor: FailureResultProcessor.new, observer: failure_observer).process(event)

    skipped_observer = RecordingObserver.new
    CDC::Core::Router.new(processor: SkippedProcessor.new, observer: skipped_observer).process(event)

    assert_equal 1, success_observer.succeeded.size
    assert_equal 1, failure_observer.failed.size
    assert_equal 1, skipped_observer.skipped.size
  end
  # rubocop:enable Metrics/AbcSize

  def test_pipeline_observes_failure_result_returned_by_processor
    observer = RecordingObserver.new
    result = CDC::Core::Pipeline.new(processor: FailureResultProcessor.new, observer: observer).process(event)

    assert_predicate result, :failure?
    assert_equal [result], observer.failed
  end

  def test_pipeline_observes_skipped_result_returned_by_processor
    observer = RecordingObserver.new
    result = CDC::Core::Pipeline.new(processor: SkippedProcessor.new, observer: observer).process(event)

    assert_predicate result, :skipped?
    assert_equal [result], observer.skipped
  end

  def test_composite_processor_observes_success_failure_and_skipped_results
    observer = RecordingObserver.new
    processor = CDC::Core::CompositeProcessor.new(
      [EventProcessor.new, FailureResultProcessor.new, SkippedProcessor.new],
      fail_fast: false,
      observer: observer
    )

    results = processor.process(event)

    assert_equal 3, results.size
    assert_equal 1, observer.succeeded.size
    assert_equal 1, observer.failed.size
    assert_equal 1, observer.skipped.size
  end

  def test_event_metadata_serializes_values_ractor_cannot_make_shareable
    unshareable = proc { :not_shareable }
    metadata = CDC::Core::EventMetadata.new(callback: unshareable)

    assert_equal unshareable.inspect, metadata[:callback]
    assert Ractor.shareable?(metadata[:callback])
  end

  def test_ordering_policy_key_components_returns_nil_for_unreachable_unknown_scope
    policy = CDC::Core::OrderingPolicy.allocate
    policy.instance_variable_set(:@scope, :unknown)

    assert_nil policy.send(:key_components, event)
  end

  def test_router_observe_result_ignores_unreachable_unknown_processor_status
    observer = RecordingObserver.new
    router = CDC::Core::Router.new(processor: EventProcessor.new, observer: observer)
    result = CDC::Core::ProcessorResult.allocate
    result.instance_variable_set(:@status, :unknown)

    assert_same result, router.send(:observe_result, result)
    assert_empty observer.succeeded
    assert_empty observer.failed
    assert_empty observer.skipped
  end

  def test_pipeline_observe_result_ignores_unreachable_unknown_processor_status
    observer = RecordingObserver.new
    pipeline = CDC::Core::Pipeline.new(processor: EventProcessor.new, observer: observer)
    result = CDC::Core::ProcessorResult.allocate
    result.instance_variable_set(:@status, :unknown)

    assert_nil pipeline.send(:observe_result, result)
    assert_empty observer.succeeded
    assert_empty observer.failed
    assert_empty observer.skipped
  end

  def test_composite_processor_observe_results_ignores_unreachable_unknown_processor_status
    observer = RecordingObserver.new
    processor = CDC::Core::CompositeProcessor.new([EventProcessor.new], observer: observer)
    result = CDC::Core::ProcessorResult.allocate
    result.instance_variable_set(:@status, :unknown)

    assert_equal [result], processor.send(:observe_results, [result])
    assert_empty observer.succeeded
    assert_empty observer.failed
    assert_empty observer.skipped
  end

  def test_router_observe_result_returns_non_processor_results_unchanged
    router = CDC::Core::Router.new(processor: EventProcessor.new)

    assert_equal :raw, router.send(:observe_result, :raw)
  end
end
# rubocop:enable Metrics/ClassLength
