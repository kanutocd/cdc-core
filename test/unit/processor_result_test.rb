# frozen_string_literal: true

require 'test_helper'

class ProcessorResultTest < Minitest::Test
  def event(operation: :update, metadata: {})
    CDC::Core::ChangeEvent.new(
      operation: operation,
      schema: :public,
      table: :users,
      old_values: { id: 1, email: 'old@example.com' },
      new_values: { id: 1, email: 'new@example.com', name: 'Alice' },
      metadata: metadata
    )
  end

  def test_success
    result = CDC::Core::ProcessorResult.success(nil, metadata: { ok: true })

    assert_predicate result, :success?
    refute_predicate result, :failure?
    assert_equal :success, result.status
    assert Ractor.shareable?(result)
  end

  def test_failure
    error = RuntimeError.new('boom')
    result = CDC::Core::ProcessorResult.failure(error, retryable: true, processor: 'AuditProcessor')

    assert_predicate result, :failure?
    assert_equal error, result.error
    assert_predicate result, :retryable?
    assert_kind_of String, result.failed_at
    assert_empty result.error_backtrace
  end

  def test_failure_metadata_projection
    error = RuntimeError.new('boom')
    result = CDC::Core::ProcessorResult.failure(error, retryable: true, processor: 'AuditProcessor')

    assert_equal 'RuntimeError', result.error_class
    assert_equal 'boom', result.error_message
    assert_equal 'boom', result.failure_reason
    assert_equal 'AuditProcessor', result.processor_name
  end

  def test_skipped
    assert_predicate CDC::Core::ProcessorResult.skipped, :skipped?
  end

  def test_processor_result_accepts_event_metadata
    metadata = CDC::Core::EventMetadata.new(reason: :filtered)
    result = CDC::Core::ProcessorResult.skipped(event, metadata: metadata)

    assert_same metadata, result.metadata
    assert_predicate result, :skipped?
  end

  def test_failure_merges_structured_metadata_with_custom_metadata
    error = RuntimeError.new('boom')
    result = CDC::Core::ProcessorResult.failure(
      error,
      metadata: { severity: :high },
      reason: 'processor exploded',
      retryable: false,
      processor: 'AuditProcessor',
      failed_at: '2026-06-07T12:00:00.000000Z'
    )

    assert_equal 'processor exploded', result.failure_reason
    refute_predicate result, :retryable?
    assert_equal 'AuditProcessor', result.processor_name
    assert_equal '2026-06-07T12:00:00.000000Z', result.failed_at
    assert_equal :high, result.metadata[:severity]
  end

  def test_to_h_returns_shareable_payload
    result = CDC::Core::ProcessorResult.success(event, metadata: { ok: true })

    hash = result.to_h

    assert_equal :success, hash['status']
    assert_equal event.to_h, hash['event']
    assert hash['metadata']['ok']
    assert Ractor.shareable?(hash)
  end

  def test_rejects_unknown_status
    error = assert_raises(ArgumentError) do
      CDC::Core::ProcessorResult.new(:maybe)
    end

    assert_match(/unsupported processor result status/, error.message)
  end
end
