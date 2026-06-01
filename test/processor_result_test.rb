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
    assert Ractor.shareable?(result)
  end

  def test_failure
    error = RuntimeError.new('boom')
    result = CDC::Core::ProcessorResult.failure(error)

    assert_predicate result, :failure?
    assert_equal error, result.error
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
end
