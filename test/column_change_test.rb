# frozen_string_literal: true

require 'test_helper'

class ColumnChangeTest < Minitest::Test
  def test_changed
    change = CDC::Core::ColumnChange.new(name: :email, old_value: 'a', new_value: 'b')

    assert_predicate change, :changed?
    assert_equal 'email', change.name
    assert Ractor.shareable?(change)
    assert_predicate change.to_h, :frozen?
  end

  def test_unchanged
    change = CDC::Core::ColumnChange.new(name: 'id', old_value: 1, new_value: 1)

    refute_predicate change, :changed?
  end

  def test_falls_back_to_inspect_when_value_is_not_shareable
    value = Mutex.new

    change = CDC::Core::ColumnChange.new(
      name: :status,
      old_value: value,
      new_value: 'new'
    )

    assert_equal value.inspect, change.old_value
  end
end
