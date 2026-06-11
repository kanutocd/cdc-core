# frozen_string_literal: true

module CDC
  module Core
    # Base class for CDC event processors.
    #
    # Subclasses implement #process and may opt into Ractor-safe execution by
    # calling .ractor_safe!. cdc-core itself does not schedule Ractors; it only
    # records processor capabilities for runtime layers such as cdc-ractor.
    class Processor
      # Mark this processor class as safe to execute in Ractor-aware runtimes.
      #
      # @return [true] marker value confirming the class was marked Ractor-safe
      def self.ractor_safe!
        @ractor_safe = true
      end

      # Whether this processor class has declared Ractor safety.
      #
      # @return [Boolean] true when the class has declared Ractor safety
      def self.ractor_safe?
        @ractor_safe == true
      end

      # Whether this processor instance is Ractor-safe.
      #
      # @return [Boolean] true when the instance's class has declared Ractor safety
      def ractor_safe?
        self.class.ractor_safe?
      end

      # Start the processor.
      #
      # Runtime layers can call this before dispatch begins. The default
      # implementation is a no-op.
      #
      # @return [self] started processor instance
      def start
        self
      end

      # Stop the processor.
      #
      # Runtime layers can call this during shutdown. The default implementation
      # is a no-op.
      #
      # @return [self] stopped processor instance
      def stop
        self
      end

      # Flush any buffered work.
      #
      # Runtime layers can call this before shutdown or checkpoints. The
      # default implementation is a no-op.
      #
      # @return [self] flushed processor instance
      def flush
        self
      end

      # Whether the processor is healthy and ready to accept work.
      #
      # The default implementation assumes the processor is healthy.
      #
      # @return [Boolean] true when the processor can accept work
      def healthy?
        true
      end

      # Process one event.
      #
      # Subclasses must override this method.
      #
      # @param _event [ChangeEvent] event to process
      # @raise [NotImplementedError] when not implemented by a subclass
      def process(_event)
        raise NotImplementedError, "#{self.class} must implement #process"
      end
    end
  end
end
