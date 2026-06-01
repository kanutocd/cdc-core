# frozen_string_literal: true

module CDC
  module Core
    # Processor that delegates each event to multiple processors.
    #
    # CompositeProcessor enables fan-out processing while preserving a simple
    # sequential execution model. It normalizes truthy/falsey processor returns
    # into ProcessorResult objects and can stop at the first failure.
    class CompositeProcessor < Processor
      # @return [Array<Processor>] processors executed for each event
      # @return [Boolean] whether processing stops on the first failure
      attr_reader :processors, :fail_fast

      # Build a composite processor.
      #
      # @param processors [Array<#process>] processors to execute
      # @param fail_fast [Boolean] whether to stop after the first failure
      def initialize(processors, fail_fast: true) # rubocop:disable Lint/MissingSuper
        @processors = processors.freeze
        @fail_fast = fail_fast
      end

      # Process an event through each configured processor.
      #
      # @param event [ChangeEvent] event to process
      # @return [Array<ProcessorResult>] result from each attempted processor
      def process(event)
        results = []
        processors.each do |processor|
          result = normalize_result(processor.process(event), event)
          results << result
          break if fail_fast && result.failure?
        rescue StandardError => e
          result = ProcessorResult.failure(e, event:)
          results << result
          break if fail_fast
        end
        Ractor.make_shareable(results.freeze) if results.none?(&:failure?)
        results.freeze
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
    end
  end
end
