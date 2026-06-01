# frozen_string_literal: true

require 'test_helper'

class ProcessorTest < Minitest::Test
  class RactorProcessor < CDC::Core::Processor
    ractor_safe!
  end

  def test_ractor_safe_declaration
    assert_predicate RactorProcessor.new, :ractor_safe?
  end

  def test_base_process_must_be_implemented
    assert_raises(NotImplementedError) { CDC::Core::Processor.new.process(Object.new) }
  end
end
