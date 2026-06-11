# frozen_string_literal: true

module CDC
  module Core
    # Abstract base class for source adapters that normalize upstream payloads
    # into CDC core domain objects.
    #
    # SourceAdapter is intentionally narrow. It does not own transport,
    # polling, connection management, worker scheduling, or protocol parsing.
    # It only defines the contract for turning source-specific inputs into
    # {ChangeEvent}, {TransactionEnvelope}, or arrays of those objects.
    #
    # The concrete PostgreSQL implementation currently lives in the pgoutput*
    # family. This class only defines the shared boundary other adapters can
    # implement later.
    class SourceAdapter
      # Normalize one source payload into CDC core objects.
      #
      # Subclasses must override this method.
      #
      # @param _input [Object] source-specific payload
      # @return [ChangeEvent,TransactionEnvelope, Array<ChangeEvent>, Array<TransactionEnvelope>] normalized core object or objects # rubocop:disable Layout/LineLength
      # @raise [NotImplementedError] when not implemented by a subclass
      def normalize(_input)
        raise NotImplementedError, "#{self.class} must implement #normalize"
      end

      # Normalize many source payloads into CDC core objects.
      #
      # The default implementation maps each input through {#normalize} and
      # flattens one level so adapters can return a single object or a batch of
      # objects for each payload.
      #
      # @param inputs [Enumerable] source-specific payloads
      # @return [Array] flattened normalized core objects
      def normalize_many(inputs)
        Array(inputs).flat_map { |input| normalize(input) }.freeze
      end
    end
  end
end
