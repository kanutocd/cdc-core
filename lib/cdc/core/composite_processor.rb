# frozen_string_literal: true

module CDC
  module Core
    # Fan-out processor that delegates the same input to multiple processors.
    #
    # CompositeProcessor is for independent downstream side effects. Every
    # configured processor receives the same input, and their results are
    # collected independently. Use ProcessorChain when Processor B must receive
    # Processor A's output.
    class CompositeProcessor < Processor
      # @return [Array<Processor>] processors executed for each event
      # @return [Boolean] whether processing stops on the first failure
      # @return [Observer] observer notified of dispatch events
      attr_reader :processors, :fail_fast, :observer

      # Build a composite processor.
      #
      # @param processors [Array<#process>] processors to execute
      # @param fail_fast [Boolean] whether to stop after the first failure
      def initialize(processors, fail_fast: true, observer: NullObserver::INSTANCE) # rubocop:disable Lint/MissingSuper
        @processors = processors.freeze
        @fail_fast = fail_fast
        @observer = observer || NullObserver::INSTANCE
      end

      # Process an event through each configured processor.
      #
      # @param event [ChangeEvent] event to process
      # @return [Array<ProcessorResult>] result from each attempted processor
      def process(event)
        observer.dispatch_started(event)
        results = collect_results(event)
        final_results = results.freeze
        observe_results(final_results)
        Ractor.make_shareable(final_results) if results.none?(&:failure?)
        final_results
      end

      # Processors that declared Ractor safety.
      #
      # @return [Array<Processor>]
      def ractor_safe_processors
        processors.select(&:ractor_safe?).freeze
      end

      # Processors that should remain sequential in the core runtime.
      #
      # @return [Array<Processor>]
      def sequential_processors
        processors.reject(&:ractor_safe?).freeze
      end

      private

      # Normalize processor return values into ProcessorResult objects.
      #
      # @param result [Object] raw processor result
      # @param event [ChangeEvent] processed event
      # @return [ProcessorResult]
      def normalize_result(result, event)
        return result if result.is_a?(ProcessorResult)

        result ? ProcessorResult.success(event) : ProcessorResult.skipped(event)
      end

      def collect_results(event)
        results = [] # : Array[ProcessorResult]
        processors.each do |processor|
          result = process_with(processor, event)
          results << result
          break if fail_fast && result.failure?
        end
        results
      end

      def process_with(processor, event)
        normalize_result(processor.process(event), event)
      rescue StandardError => e
        ProcessorResult.failure(e, event:, processor: processor.class.name)
      end

      def observe_results(results)
        results.each do |result|
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
end
