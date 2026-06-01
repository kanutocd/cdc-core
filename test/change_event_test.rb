# frozen_string_literal: true

require 'test_helper'

class ChangeEventTest < Minitest::Test
  def event
    CDC::Core::ChangeEvent.new(
      operation: :update,
      schema: 'public',
      table: 'users',
      old_values: { 'id' => 7, 'email' => 'old@example.com' },
      new_values: { 'id' => 7, 'email' => 'new@example.com' },
      primary_key: { 'id' => 7 },
      transaction_id: 123,
      commit_lsn: '0/16B6C50',
      sequence_number: 1,
      metadata: { source: 'postgres' }
    )
  end

  def test_constructs_shareable_event
    assert_equal :update, event.operation
    assert_equal 'public.users', event.qualified_table_name
    assert Ractor.shareable?(event)
  end

  def test_predicates
    assert_predicate event, :update?
    refute_predicate event, :insert?
    refute_predicate event, :delete?
  end

  def test_changes_returns_changed_columns_only
    changes = event.changes

    assert_equal 1, changes.size
    assert_equal 'email', changes.first.name
    assert_equal 'old@example.com', changes.first.old_value
    assert_equal 'new@example.com', changes.first.new_value
    assert Ractor.shareable?(changes)
  end

  def test_to_h
    hash = event.to_h

    assert_equal 'users', hash['table']
    assert_equal 'postgres', hash['metadata']['source']
    assert Ractor.shareable?(hash)
  end

  def test_changes_handles_nil_old_values
    event = CDC::Core::ChangeEvent.new(
      operation: CDC::Core::Operation::INSERT,
      schema: 'public',
      table: 'users',
      old_values: nil,
      new_values: { 'name' => 'Alice' }
    )

    changes = event.changes

    assert_equal 1, changes.length
    assert_equal 'name', changes.first.name
    assert_nil changes.first.old_value
    assert_equal 'Alice', changes.first.new_value
  end

  def test_changes_handles_nil_new_values
    event = CDC::Core::ChangeEvent.new(
      operation: CDC::Core::Operation::DELETE,
      schema: 'public',
      table: 'users',
      old_values: { 'name' => 'Alice' },
      new_values: nil
    )

    changes = event.changes

    assert_equal 1, changes.length
    assert_equal 'name', changes.first.name
    assert_equal 'Alice', changes.first.old_value
    assert_nil changes.first.new_value
  end
end
