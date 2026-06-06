# frozen_string_literal: true

require 'test_helper'

class ObserverTest < Minitest::Test
  class RecordingObserver < CDC::Core::Observer
    attr_reader :events

    def initialize
      super
      @events = []
    end

    def dispatch_started(item)
      events << [:started, item.class.name]
    end

    def dispatch_succeeded(result)
      events << [:succeeded, result.status]
    end

    def dispatch_failed(result)
      events << [:failed, result.status]
    end

    def dispatch_skipped(result)
      events << [:skipped, result.status]
    end
  end

  class SuccessProcessor < CDC::Core::Processor
    def process(event)
      CDC::Core::ProcessorResult.success(event)
    end
  end

  class FailureProcessor < CDC::Core::Processor
    def process(_event)
      raise 'boom'
    end
  end

  def event
    CDC::Core::ChangeEvent.new(operation: :insert, schema: 'public', table: 'users')
  end

  def test_pipeline_notifies_observer
    observer = RecordingObserver.new
    pipeline = CDC::Core::Pipeline.new(
      processor: SuccessProcessor.new,
      observer: observer
    )

    result = pipeline.process(event)

    assert_predicate result, :success?
    assert_equal [[:started, 'CDC::Core::ChangeEvent'], %i[succeeded success]], observer.events
  end

  def test_pipeline_notifies_failure
    observer = RecordingObserver.new
    pipeline = CDC::Core::Pipeline.new(
      processor: FailureProcessor.new,
      observer: observer
    )

    result = pipeline.process(event)

    assert_predicate result, :failure?
    assert_equal [[:started, 'CDC::Core::ChangeEvent'], %i[failed failure]], observer.events
  end

  def test_router_notifies_observer
    observer = RecordingObserver.new
    router = CDC::Core::Router.new(processor: SuccessProcessor.new, observer: observer)

    result = router.process(event)

    assert_predicate result, :success?
    assert_equal [[:started, 'CDC::Core::ChangeEvent'], %i[succeeded success]], observer.events
  end
end
