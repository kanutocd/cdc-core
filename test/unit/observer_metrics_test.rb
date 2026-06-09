# frozen_string_literal: true

require 'test_helper'

class ObserverMetricsTest < Minitest::Test
  def event
    CDC::Core::ChangeEvent.new(
      operation: :update,
      schema: 'public',
      table: 'users',
      transaction_id: 7
    )
  end

  def transaction
    CDC::Core::TransactionEnvelope.new(transaction_id: 9, events: [event])
  end

  def result
    CDC::Core::ProcessorResult.failure(
      RuntimeError.new('boom'),
      event: event,
      processor: 'AuditProcessor',
      retryable: false,
      reason: 'invalid payload'
    )
  end

  def test_metric_names_are_canonical
    assert_equal 'cdc_core.dispatch.started', CDC::Core::Observer.started_metric_name
    assert_equal 'cdc_core.dispatch.succeeded', CDC::Core::Observer.succeeded_metric_name
    assert_equal 'cdc_core.dispatch.failed', CDC::Core::Observer.failed_metric_name
    assert_equal 'cdc_core.dispatch.skipped', CDC::Core::Observer.skipped_metric_name
  end

  def test_metric_tags_for_change_events
    tags = CDC::Core::Observer.metric_tags(event)

    assert_equal 'change_event', tags['kind']
    assert_equal :update, tags['operation']
    assert_equal 'public', tags['schema']
    assert_equal 'users', tags['table']
    assert_equal 7, tags['transaction_id']
    assert Ractor.shareable?(tags)
  end

  def test_metric_tags_for_transactions
    tags = CDC::Core::Observer.metric_tags(transaction)

    assert_equal 'transaction_envelope', tags['kind']
    assert_equal 9, tags['transaction_id']
    assert_equal 1, tags['size']
  end

  def test_metric_tags_for_results
    tags = CDC::Core::Observer.metric_tags(result)

    assert_equal 'processor_result', tags['kind']
    assert_equal :failure, tags['status']
    assert_equal 'AuditProcessor', tags['processor']
    refute tags['retryable']
    assert_equal 'invalid payload', tags['failure_reason']
  end

  def test_metric_tags_for_batches
    tags = CDC::Core::Observer.metric_tags([event, event])

    assert_equal 'batch', tags['kind']
    assert_equal 2, tags['size']
  end
end
