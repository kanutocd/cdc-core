# frozen_string_literal: true

module CDC
  module Core
    # Result returned by processors and pipelines.
    #
    # ProcessorResult standardizes processor outcomes so callers can distinguish
    # successful processing, skipped events, and failures without relying on
    # processor-specific return values.
    class ProcessorResult
      # @return [Symbol] result status
      # @return [ChangeEvent, nil] event associated with the result
      # @return [Exception, nil] failure error, when status is :failure
      # @return [EventMetadata] result metadata
      attr_reader :status, :event, :error, :metadata

      # Build a successful result.
      #
      # @param event [ChangeEvent, nil] processed event
      # @param metadata [Hash, EventMetadata] result metadata
      # @return [ProcessorResult]
      def self.success(event = nil, metadata: {}) = new(:success, event:, metadata:)

      # Build a failure result.
      #
      # @param error [Exception] processor error
      # @param event [ChangeEvent, nil] event being processed
      # @param metadata [Hash, EventMetadata] result metadata
      # @return [ProcessorResult]
      def self.failure(error, event: nil, metadata: {}) = new(:failure, event:, error:, metadata:)

      # Build a skipped result.
      #
      # @param event [ChangeEvent, nil] skipped event
      # @param metadata [Hash, EventMetadata] result metadata
      # @return [ProcessorResult]
      def self.skipped(event = nil, metadata: {}) = new(:skipped, event:, metadata:)

      # Build a processor result with an explicit status.
      #
      # @param status [#to_sym] result status
      # @param event [ChangeEvent, nil] associated event
      # @param error [Exception, nil] associated failure
      # @param metadata [Hash, EventMetadata] result metadata
      def initialize(status, event: nil, error: nil, metadata: {})
        @status = status.to_sym
        @event = event
        @error = error
        @metadata = metadata.is_a?(EventMetadata) ? metadata : EventMetadata.new(metadata)
        Ractor.make_shareable(self) unless error
      end

      # @return [Boolean] true when status is :success
      def success? = status == :success

      # @return [Boolean] true when status is :failure
      def failure? = status == :failure

      # @return [Boolean] true when status is :skipped
      def skipped? = status == :skipped
    end
  end
end
