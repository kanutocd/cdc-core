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
      # @return [true]
      def self.ractor_safe!
        @ractor_safe = true
      end

      # Whether this processor class has declared Ractor safety.
      #
      # @return [Boolean]
      def self.ractor_safe?
        @ractor_safe == true
      end

      # Whether this processor instance is Ractor-safe.
      #
      # @return [Boolean]
      def ractor_safe?
        self.class.ractor_safe?
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
