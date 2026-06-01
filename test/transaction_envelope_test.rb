# frozen_string_literal: true

require 'test_helper'

class TransactionEnvelopeTest < Minitest::Test
  def test_groups_events
    event = CDC::Core::ChangeEvent.new(operation: :insert, schema: 'public', table: 'users', new_values: { 'id' => 1 })
    envelope = CDC::Core::TransactionEnvelope.new(transaction_id: 9, events: [event], commit_lsn: '0/1')

    assert_equal 1, envelope.size
    refute_empty envelope
    assert_equal '0/1', envelope.commit_lsn
    assert Ractor.shareable?(envelope)
  end

  def test_transaction_envelope_empty_with_event_metadata_and_nil_lsn
    metadata = CDC::Core::EventMetadata.new(source: :test)
    envelope = CDC::Core::TransactionEnvelope.new(transaction_id: 1, events: [], metadata: metadata)

    assert_empty envelope
    assert_equal 0, envelope.size
    assert_nil envelope.commit_lsn
    assert_same metadata, envelope.metadata
    assert_empty envelope.to_h['events']
  end
end
