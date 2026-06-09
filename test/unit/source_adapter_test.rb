# frozen_string_literal: true

require 'test_helper'

class SourceAdapterTest < Minitest::Test
  class DemoSourceAdapter < CDC::Core::SourceAdapter
    def normalize(input)
      case input
      when :batch then batch_events
      when :transaction then transaction_envelope
      else
        event(operation: input, table: 'users', primary_key: { 'id' => 1 })
      end
    end

    private

    def event(operation:, table:, primary_key:)
      CDC::Core::ChangeEvent.new(
        operation: operation,
        schema: 'public',
        table: table,
        primary_key: primary_key
      )
    end

    def batch_events
      [
        event(operation: :insert, table: 'users', primary_key: { 'id' => 1 }),
        event(operation: :update, table: 'users', primary_key: { 'id' => 2 })
      ]
    end

    def transaction_envelope
      CDC::Core::TransactionEnvelope.new(
        transaction_id: 9,
        events: [
          event(operation: :insert, table: 'orders', primary_key: { 'id' => 7 })
        ],
        commit_lsn: '0/1'
      )
    end
  end

  def test_source_adapter_requires_normalize
    assert_raises(NotImplementedError) { CDC::Core::SourceAdapter.new.normalize(Object.new) }
  end

  def test_source_adapter_normalize_many_flattens_single_and_batched_payloads
    adapter = DemoSourceAdapter.new
    items = adapter.normalize_many(%i[insert batch transaction])

    assert_equal 4, items.length
    assert_instance_of CDC::Core::ChangeEvent, items[0]
    assert_instance_of CDC::Core::ChangeEvent, items[1]
    assert_instance_of CDC::Core::ChangeEvent, items[2]
    assert_instance_of CDC::Core::TransactionEnvelope, items[3]
    assert_predicate items, :frozen?
  end
end
