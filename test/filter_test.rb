# frozen_string_literal: true

require 'test_helper'

class FilterTest < Minitest::Test
  def event
    CDC::Core::ChangeEvent.new(operation: :update, schema: 'public', table: 'users')
  end

  def test_table_filter
    assert_match CDC::Core::Filter.table('users'), event
    refute_match CDC::Core::Filter.table('orders'), event
  end

  def test_operation_filter
    assert_match CDC::Core::Filter.operation(:update), event
  end

  def test_composed_filters
    filter = CDC::Core::Filter.schema('public') & CDC::Core::Filter.table('users')

    assert_match filter, event
  end

  def test_filter_requires_predicate
    assert_raises(ArgumentError) { CDC::Core::Filter.new }
  end

  def test_filter_or_short_circuits_and_matches_second_filter
    filter = CDC::Core::Filter.table('orders') | CDC::Core::Filter.schema('public')

    assert_match filter, event
  end

  def test_filter_match_requires_true_not_truthy
    filter = CDC::Core::Filter.new { |_event| :truthy }

    refute_match filter, event
  end
end
