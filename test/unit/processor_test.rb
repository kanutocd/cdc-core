# frozen_string_literal: true

require 'test_helper'

class ProcessorTest < Minitest::Test
  class RactorProcessor < CDC::Core::Processor
    ractor_safe!
  end

  class LifecycleProcessor < CDC::Core::Processor
    attr_reader :events

    def initialize
      super
      @events = []
    end

    def start
      events << :start
      super
    end

    def stop
      events << :stop
      super
    end

    def flush
      events << :flush
      super
    end

    def healthy?
      events << :healthy
      false
    end
  end

  def test_ractor_safe_declaration
    assert_predicate RactorProcessor.new, :ractor_safe?
  end

  def test_processor_lifecycle_defaults
    processor = CDC::Core::Processor.new

    assert_same processor, processor.start
    assert_same processor, processor.stop
    assert_same processor, processor.flush
    assert_predicate processor, :healthy?
  end

  def test_processor_lifecycle_can_be_overridden
    processor = LifecycleProcessor.new

    assert_same processor, processor.start
    assert_same processor, processor.stop
    assert_same processor, processor.flush
    refute_predicate processor, :healthy?
    assert_equal %i[start stop flush healthy], processor.events
  end

  def test_base_process_must_be_implemented
    assert_raises(NotImplementedError) { CDC::Core::Processor.new.process(Object.new) }
  end
end
