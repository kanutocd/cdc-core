# frozen_string_literal: true

require 'test_helper'

class EventMetadataTest < Minitest::Test
  def test_event_metadata_reads_existing_string_symbol_and_symbolized_keys
    metadata = CDC::Core::EventMetadata.new('string' => 1, symbol: 2)

    assert_equal 1, metadata['string']
    assert_equal 1, metadata[:string]
    assert_equal 2, metadata['symbol']
  end

  def test_event_metadata_preserves_false_and_nil_values
    metadata = CDC::Core::EventMetadata.new(enabled: false, note: nil)

    assert_same false, metadata[:enabled]
    assert_nil metadata[:note]
    assert metadata.to_h.key?('note')
  end

  def test_event_metadata_normalizes_nested_arrays_hashes_and_unshareable_values
    object = Object.new
    metadata = CDC::Core::EventMetadata.new(
      nested: { tags: [:a, { b: object }] }
    )

    assert_equal 'a', metadata[:nested]['tags'].first.to_s
    assert_equal object.inspect, metadata[:nested]['tags'].last['b'].inspect
    assert Ractor.shareable?(metadata)
    assert Ractor.shareable?(metadata.to_h)
  end

  def test_change_event_accepts_event_metadata_and_nil_values
    metadata = CDC::Core::EventMetadata.new(source: :test)
    event = CDC::Core::ChangeEvent.new(operation: :delete, schema: :public, table: :users, metadata: metadata)

    assert_predicate event, :delete?
    refute_predicate event, :update?
    assert_same metadata, event.metadata
    assert_nil event.old_values
    assert_nil event.new_values
    assert_empty event.changes
  end
end
