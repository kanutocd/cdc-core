# frozen_string_literal: true

require 'test_helper'

class OperationTest < Minitest::Test
  def test_normalizes_supported_operation
    assert_equal :insert, CDC::Core::Operation.normalize('insert')
  end

  def test_rejects_unknown_operation
    assert_raises(CDC::Core::InvalidOperationError) { CDC::Core::Operation.normalize(:merge) }
  end

  def test_rejects_nil_operation_with_domain_error
    assert_raises(CDC::Core::InvalidOperationError) { CDC::Core::Operation.normalize(nil) }
  end

  def test_supported_predicate
    assert CDC::Core::Operation.supported?(:update)
    refute CDC::Core::Operation.supported?(Object.new)
  end
end
