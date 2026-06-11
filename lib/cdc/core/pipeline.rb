# frozen_string_literal: true

module CDC
  module Core
    # Connects filters with one processor to form a guarded processing unit.
    #
    # A Pipeline evaluates all filters before invoking its processor. Matching
    # inputs are processed, while filtered inputs produce skipped results. Use
    # CompositeProcessor for fan-out to many processors and ProcessorChain for
    # dependent step-by-step workflows.
    class Pipeline
      # @return [#process] processor invoked for matching events
      # @return [Array<Filter>] filters that must all match before processing
      # @return [Observer] observer notified of dispatch events
      attr_reader :processor, :filters, :observer

      # Build a pipeline.
      #
      # @param processor [#process] processor for matching events
      # @param filters [Array<Filter>] filters applied before processing
      # @param observer [Observer, nil] instrumentation observer
      def initialize(processor:, filters: [], observer: NullObserver::INSTANCE)
        @processor = processor
        @filters = filters.freeze
        @observer = observer || NullObserver::INSTANCE
      end

      # Process one event through the pipeline.
      #
      # @param event [ChangeEvent] event to process
      # @return [ProcessorResult] result for the event
      def process(event)
        observer.dispatch_started(event)
        return ProcessorResult.skipped(event, metadata: { reason: 'filtered' }) unless matches?(event)

        result = normalize_result(processor.process(event), event)
        observe_result(result)
        result
      rescue StandardError => e
        result = ProcessorResult.failure(e, event:, processor: processor.class.name)
        observer.dispatch_failed(result)
        result
      end

      # Process many events in order.
      #
      # @param events [Enumerable<ChangeEvent>] events to process
      # @return [Array<ProcessorResult>] results in input order
      def process_many(events)
        events.map { |event| process(event) }.freeze
      end

      private

      # Check whether every filter matches an event.
      #
      # @param event [ChangeEvent] event to test
      # @return [Boolean] true when every filter matches
      def matches?(event)
        filters.all? { |filter| filter.match?(event) }
      end

      # Normalize raw processor output into a ProcessorResult.
      #
      # @param result [Object] raw processor result
      # @param event [ChangeEvent] processed event
      # @return [ProcessorResult] normalized processor result
      def normalize_result(result, event)
        return result if result.is_a?(ProcessorResult)

        result ? ProcessorResult.success(event) : ProcessorResult.skipped(event)
      end

      def observe_result(result)
        case result.status
        when :success
          observer.dispatch_succeeded(result)
        when :failure
          observer.dispatch_failed(result)
        when :skipped
          observer.dispatch_skipped(result)
        end
      end
    end
  end
end
