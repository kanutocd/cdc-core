# frozen_string_literal: true

module CDC
  module Core
    # Sequential processor workflow where each successful result feeds the next processor.
    #
    # ProcessorChain models dependent workflows. Unlike CompositeProcessor,
    # which sends the same input to every processor, ProcessorChain sends the
    # value returned by one processor to the next processor. This is useful for
    # downstream workflows such as loading records, enriching them, and then
    # sending the enriched payload to a sink.
    #
    # Each processor result is normalized into a ProcessorResult. The chain stops
    # at the first failure or skipped result because later processors depend on
    # the previous processor's successful value.
    class ProcessorChain < Processor
      # @return [Array<#process>] processors executed in dependency order
      # @return [Observer] observer notified of dispatch events
      attr_reader :processors, :observer

      # Build a processor chain.
      #
      # @param processors [Array<#process>] processors executed in dependency order
      # @param observer [Observer, nil] instrumentation observer for each processor result
      def initialize(processors, observer: NullObserver::INSTANCE) # rubocop:disable Lint/MissingSuper
        @processors = processors.freeze
        @observer = observer || NullObserver::INSTANCE
      end

      # Process one input through each processor in sequence.
      #
      # The first processor receives the original input. Each later processor
      # receives the previous successful ProcessorResult#value. The returned
      # value is the final ProcessorResult produced by the chain.
      #
      # @param input [Object] initial input for the first processor
      # @return [ProcessorResult] final processor result or the first failed or skipped result
      def process(input)
        observer.dispatch_started(input)
        current_input = input

        processors.each do |processor|
          result = process_with(processor, current_input)
          observe_result(result)
          return result unless result.success?

          current_input = result.value
        end

        ProcessorResult.success(current_input, value: current_input)
      end

      # Process many inputs in order.
      #
      # @param inputs [Enumerable<Object>] inputs to process through the chain
      # @return [Array<ProcessorResult>] final result for each input
      def process_many(inputs)
        inputs.map { |input| process(input) }.freeze
      end

      private

      # Normalize processor return values into ProcessorResult objects.
      #
      # @param result [Object] raw processor result
      # @param input [Object] input given to the processor
      # @return [ProcessorResult] normalized result
      def normalize_result(result, input)
        return result if result.is_a?(ProcessorResult)

        result ? ProcessorResult.success(input, value: result) : ProcessorResult.skipped(input)
      end

      def process_with(processor, input)
        normalize_result(processor.process(input), input)
      rescue StandardError => e
        ProcessorResult.failure(e, event: input, processor: processor.class.name)
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
