# frozen_string_literal: true

require 'test_helper'

class CompositeProcessorTest < Minitest::Test
  class TruthyProcessor < CDC::Core::Processor
    def process(_event) = true # rubocop:disable Naming/PredicateMethod
  end

  class FalseyProcessor < CDC::Core::Processor
    def process(_event) = false # rubocop:disable Naming/PredicateMethod
  end

  class SuccessProcessor < CDC::Core::Processor
    ractor_safe!

    def process(event)
      CDC::Core::ProcessorResult.success(event)
    end
  end

  class FailureProcessor < CDC::Core::Processor
    def process(_event)
      raise 'boom'
    end
  end

  class RaisingProcessor < CDC::Core::Processor
    def process(_event)
      raise 'boom'
    end
  end

  class ExplicitFailureProcessor < CDC::Core::Processor
    def process(event)
      CDC::Core::ProcessorResult.failure(RuntimeError.new('explicit'), event: event)
    end
  end

  def event
    CDC::Core::ChangeEvent.new(operation: :insert, schema: 'public', table: 'users')
  end

  def test_runs_processors_sequentially
    processor = CDC::Core::CompositeProcessor.new([SuccessProcessor.new, SuccessProcessor.new])
    results = processor.process(event)

    assert_equal 2, results.size
    assert results.all?(&:success?)
  end

  def test_fail_fast
    processor = CDC::Core::CompositeProcessor.new([FailureProcessor.new, SuccessProcessor.new], fail_fast: true)

    assert_equal 1, processor.process(event).size
  end

  def test_classifies_ractor_safe_processors
    success = SuccessProcessor.new
    failure = FailureProcessor.new
    processor = CDC::Core::CompositeProcessor.new([success, failure])

    assert_equal [success], processor.ractor_safe_processors
    assert_equal [failure], processor.sequential_processors
  end

  def test_composite_processor_stops_on_explicit_failure_when_fail_fast_is_true
    processor = CDC::Core::CompositeProcessor.new(
      [ExplicitFailureProcessor.new, TruthyProcessor.new],
      fail_fast: true
    )

    results = processor.process(event)

    assert_equal 1, results.size
    assert_predicate results.first, :failure?
  end

  def test_composite_processor_continues_after_failure_when_fail_fast_is_false
    processor = CDC::Core::CompositeProcessor.new(
      [RaisingProcessor.new, TruthyProcessor.new, FalseyProcessor.new],
      fail_fast: false
    )

    results = processor.process(event)

    assert_equal 3, results.size
    assert_predicate results[0], :failure?
    assert_predicate results[1], :success?
    assert_predicate results[2], :skipped?
  end
end
