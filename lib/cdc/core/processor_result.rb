# frozen_string_literal: true

module CDC
  module Core
    # Result returned by processors and pipelines.
    #
    # ProcessorResult standardizes processor outcomes so callers can distinguish
    # successful processing, skipped events, and failures without relying on
    # processor-specific return values.
    class ProcessorResult
      # Allowed result statuses.
      VALID_STATUSES = Ractor.make_shareable(%i[success failure skipped].freeze)
      EMPTY_METADATA = Ractor.make_shareable(
        {} # : Hash[untyped, untyped]
          .freeze
      )

      # @return [Symbol] result status
      # @return [ChangeEvent, Object, nil] event or input associated with the result
      # @return [Object, nil] value produced by the processor
      # @return [Exception, nil] failure error, when status is :failure
      # @return [EventMetadata] result metadata
      attr_reader :status, :event, :value, :error, :metadata

      # Build a successful result.
      #
      # @param event [ChangeEvent, nil] processed event
      # @param metadata [Hash, EventMetadata] result metadata
      # @param value [Object, nil] value produced by the processor; defaults to event for compatibility
      # @return [ProcessorResult]
      def self.success(event = nil, metadata: EMPTY_METADATA, value: event) = new(:success, event:, metadata:, value:)

      # Build a failure result.
      #
      # @param error [Exception] processor error
      # @param event [ChangeEvent, nil] event being processed
      # @param reason [String, nil] human-readable failure reason
      # @param retryable [Boolean, nil] whether the failure can be retried
      # @param processor [String, nil] processor name associated with the failure
      # @param failed_at [String, nil] timestamp for when the failure occurred
      # @param metadata [Hash, EventMetadata] result metadata
      # @return [ProcessorResult]
      def self.failure(error, event: nil, reason: nil, retryable: nil, processor: nil, failed_at: nil,
                       metadata: nil)
        base_metadata = metadata.nil? ? EventMetadata.new.to_h : metadata.to_h
        failure_metadata = base_metadata.merge(
          reason: reason || error.message,
          retryable: retryable,
          processor: processor || error.class.name,
          failed_at: failed_at || Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%6NZ')
        ).compact

        new(:failure, event:, error:, metadata: failure_metadata)
      end

      # Build a skipped result.
      #
      # @param event [ChangeEvent, nil] skipped event
      # @param metadata [Hash, EventMetadata] result metadata
      # @return [ProcessorResult]
      def self.skipped(event = nil, metadata: EMPTY_METADATA) = new(:skipped, event:, metadata:)

      # Build a processor result with an explicit status.
      #
      # @param status [#to_sym] result status
      # @param event [ChangeEvent, nil] associated event
      # @param error [Exception, nil] associated failure
      # @param metadata [Hash, EventMetadata] result metadata
      # @param value [Object, nil] value produced by the processor
      def initialize(status, event: nil, error: nil, metadata: EMPTY_METADATA, value: event)
        @status = normalize_status(status)
        @event = event
        @value = value
        @error = error
        @metadata = metadata.is_a?(EventMetadata) ? metadata : EventMetadata.new(metadata)
        make_shareable_when_possible
      end

      # @return [Boolean] true when status is :success
      def success? = status == :success

      # @return [Boolean] true when status is :failure
      def failure? = status == :failure

      # @return [Boolean] true when status is :skipped
      def skipped? = status == :skipped

      # Human-readable failure reason, when present.
      #
      # @return [String, nil]
      def failure_reason
        metadata[:reason]
      end

      # Whether the failure is retryable.
      #
      # @return [Boolean]
      def retryable?
        metadata[:retryable] == true
      end

      # Name of the processor associated with the failure, when present.
      #
      # @return [String, nil]
      def processor_name
        metadata[:processor]
      end

      # Timestamp for when the failure occurred, when present.
      #
      # @return [String, nil]
      def failed_at
        metadata[:failed_at]
      end

      # Error class name, when present.
      #
      # @return [String, nil]
      def error_class
        error&.class&.name
      end

      # Error message, when present.
      #
      # @return [String, nil]
      def error_message
        error&.message
      end

      # Error backtrace, when present.
      #
      # @return [Array<String>]
      def error_backtrace
        Array(error&.backtrace)
      end

      # Convert the result into a shareable hash.
      #
      # @return [Hash{String=>Object,nil}]
      def to_h
        payload = {
          'status' => status,
          'event' => event.respond_to?(:to_h) ? event.to_h : event,
          'value' => value.respond_to?(:to_h) ? value.to_h : value,
          'error_class' => error_class,
          'error_message' => error_message,
          'error_backtrace' => error_backtrace,
          'metadata' => metadata.to_h
        }

        Ractor.make_shareable(payload.freeze)
      end

      private

      def make_shareable_when_possible
        Ractor.make_shareable(self) unless error
      rescue Ractor::Error, TypeError
        # ProcessorResult may carry application-specific values such as ActiveRecord
        # result sets. Those values are valid in sequential/fiber runtimes even when
        # they cannot be shared with Ractors. Ractor runtimes remain responsible for
        # validating shareability at their boundary.
        self
      end

      def normalize_status(status)
        value = status.to_sym
        return value if VALID_STATUSES.include?(value)

        raise ArgumentError, "unsupported processor result status: #{status.inspect}"
      rescue NoMethodError
        raise ArgumentError, "unsupported processor result status: #{status.inspect}"
      end
    end
  end
end
