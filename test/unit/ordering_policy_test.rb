# frozen_string_literal: true

require 'test_helper'

class OrderingPolicyTest < Minitest::Test
  def event
    CDC::Core::ChangeEvent.new(
      operation: :update,
      schema: 'public',
      table: 'users',
      primary_key: { id: 7 },
      transaction_id: 42,
      commit_lsn: '0/16B6C50',
      sequence_number: 3,
      occurred_at: Time.utc(2026, 6, 6, 10, 11, 12)
    )
  end

  def test_normalizes_scope_and_position
    policy = CDC::Core::OrderingPolicy.new(scope: :relation, position: :commit_lsn)

    assert_equal :relation, policy.scope
    assert_equal :commit_lsn, policy.position
    assert_predicate policy, :transaction_aware?
  end

  def test_rejects_invalid_scope
    error = assert_raises(CDC::Core::InvalidOrderingScopeError) do
      CDC::Core::OrderingPolicy.new(scope: :rack, position: :commit_lsn)
    end

    assert_match(/unsupported CDC ordering scope/, error.message)
  end

  def test_rejects_invalid_position
    error = assert_raises(CDC::Core::InvalidOrderingPositionError) do
      CDC::Core::OrderingPolicy.new(scope: :relation, position: :offset)
    end

    assert_match(/unsupported CDC ordering position/, error.message)
  end

  def test_key_for_global_scope_has_no_components
    policy = CDC::Core::OrderingPolicy.new(scope: :global)
    key = policy.key_for(event)

    assert_instance_of CDC::Core::OrderingKey, key
    assert_equal :global, key.scope
    assert_empty key.components
    assert Ractor.shareable?(key)
  end

  def test_key_for_primary_key_scope_uses_row_identity
    policy = CDC::Core::OrderingPolicy.new(scope: :primary_key)
    key = policy.key_for(event)

    assert_equal 'public', key.components['schema']
    assert_equal 'users', key.components['table']
    assert_equal({ 'id' => 7 }, key.components['primary_key'])
  end

  def test_key_for_none_scope_returns_nil
    policy = CDC::Core::OrderingPolicy.new(scope: :none)

    assert_nil policy.key_for(event)
  end

  def test_position_for_returns_shareable_event_position
    policy = CDC::Core::OrderingPolicy.new(scope: :transaction, position: :sequence_number)
    position = policy.position_for(event)

    assert_instance_of CDC::Core::EventPosition, position
    assert_equal :sequence_number, position.strategy
    assert_equal 3, position.value
    assert_equal 42, position.transaction_id
    assert Ractor.shareable?(position)
  end
end
