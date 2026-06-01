# frozen_string_literal: true

require 'test_helper'

class PipelineTest < Minitest::Test
  class EchoProcessor < CDC::Core::Processor
    def process(event)
      CDC::Core::ProcessorResult.success(event)
    end
  end

  class TruthyProcessor < CDC::Core::Processor
    def process(_event) = true # rubocop:disable Naming/PredicateMethod
  end

  class FalseyProcessor < CDC::Core::Processor
    def process(_event) = false # rubocop:disable Naming/PredicateMethod
  end

  class RaisingProcessor < CDC::Core::Processor
    def process(_event)
      raise 'boom'
    end
  end

  def event
    CDC::Core::ChangeEvent.new(operation: :insert, schema: 'public', table: 'users')
  end

  def test_processes_matching_event
    pipeline = CDC::Core::Pipeline.new(processor: EchoProcessor.new, filters: [CDC::Core::Filter.table('users')])

    assert_predicate pipeline.process(event), :success?
  end

  def test_skips_filtered_event
    pipeline = CDC::Core::Pipeline.new(processor: EchoProcessor.new, filters: [CDC::Core::Filter.table('orders')])

    assert_predicate pipeline.process(event), :skipped?
  end

  def test_process_many
    pipeline = CDC::Core::Pipeline.new(processor: EchoProcessor.new)

    assert_equal 2, pipeline.process_many([event, event]).size
  end

  def test_pipeline_normalizes_truthy_and_falsey_results
    success = CDC::Core::Pipeline.new(processor: TruthyProcessor.new).process(event)
    skipped = CDC::Core::Pipeline.new(processor: FalseyProcessor.new).process(event)

    assert_predicate success, :success?
    assert_predicate skipped, :skipped?
  end

  def test_pipeline_converts_processor_exception_to_failure
    result = CDC::Core::Pipeline.new(processor: RaisingProcessor.new).process(event)

    assert_predicate result, :failure?
    assert_equal 'boom', result.error.message
  end
end
