# frozen_string_literal: true

module CDC
  module Core
    # Connects filters with a processor to form an event-processing unit.
    #
    # A Pipeline first evaluates all filters. Matching events are handed to the
    # processor, while filtered events produce skipped results. Processor errors
    # are captured as failure results instead of escaping to the caller.
    class Pipeline
      # @return [#process] processor invoked for matching events
      # @return [Array<Filter>] filters that must all match before processing
      attr_reader :processor, :filters

      # Build a pipeline.
      #
      # @param processor [#process] processor for matching events
      # @param filters [Array<Filter>] filters applied before processing
      def initialize(processor:, filters: [])
        @processor = processor
        @filters = filters.freeze
      end

      # Process one event through the pipeline.
      #
      # @param event [ChangeEvent] event to process
      # @return [ProcessorResult]
      def process(event)
        return ProcessorResult.skipped(event, metadata: { reason: 'filtered' }) unless matches?(event)

        normalize_result(processor.process(event), event)
      rescue StandardError => e
        ProcessorResult.failure(e, event:)
      end

      # Process many events in order.
      #
      # @param events [Enumerable<ChangeEvent>] events to process
      # @return [Array<ProcessorResult>]
      def process_many(events)
        events.map { |event| process(event) }.freeze
      end

      private

      # Check whether every filter matches an event.
      #
      # @param event [ChangeEvent]
      # @return [Boolean]
      def matches?(event)
        filters.all? { |filter| filter.match?(event) }
      end

      # Normalize raw processor output into a ProcessorResult.
      #
      # @param result [Object] raw processor result
      # @param event [ChangeEvent] processed event
      # @return [ProcessorResult]
      def normalize_result(result, event)
        return result if result.is_a?(ProcessorResult)

        result ? ProcessorResult.success(event) : ProcessorResult.skipped(event)
      end
    end
  end
end
