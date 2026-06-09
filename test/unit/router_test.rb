# frozen_string_literal: true

require 'test_helper'

class RouterTest < Minitest::Test
  class EventProcessor < CDC::Core::Processor
    def process(event)
      CDC::Core::ProcessorResult.success(event)
    end
  end

  class EventBatchProcessor < CDC::Core::Processor
    def process_many(events)
      events.map { |event| CDC::Core::ProcessorResult.success(event) }.freeze
    end
  end

  class TransactionProcessor < CDC::Core::Processor
    def process(transaction)
      CDC::Core::ProcessorResult.success(transaction)
    end
  end

  def event
    CDC::Core::ChangeEvent.new(operation: :insert, schema: 'public', table: 'users')
  end

  def transaction
    CDC::Core::TransactionEnvelope.new(transaction_id: 7, events: [event])
  end

  def test_routes_change_events_to_event_processor
    router = CDC::Core::Router.new(processor: EventProcessor.new)

    result = router.process(event)

    assert_predicate result, :success?
    assert_equal event.to_h, result.event.to_h
  end

  def test_routes_transaction_envelopes_to_transaction_processor
    router = CDC::Core::Router.new(
      processor: EventProcessor.new,
      transaction_processor: TransactionProcessor.new
    )

    result = router.process(transaction)

    assert_predicate result, :success?
    assert_equal transaction.to_h, result.event.to_h
  end

  def test_routes_event_arrays_to_process_many_when_available
    router = CDC::Core::Router.new(processor: EventBatchProcessor.new)

    results = router.process([event, event])

    assert_equal 2, results.size
    assert results.all?(&:success?)
  end

  def test_raises_for_unsupported_work_item
    router = CDC::Core::Router.new(processor: EventProcessor.new)

    error = assert_raises(CDC::Core::UnsupportedWorkItemError) { router.process(Object.new) }

    assert_match(/unsupported CDC work item/, error.message)
  end
end
