# frozen_string_literal: true

module CDC
  module Core
    # Immutable group of change events committed in one transaction.
    #
    # TransactionEnvelope is useful when a downstream processor needs transaction
    # boundaries instead of isolated row-level events. The contained events and
    # metadata are Ractor-shareable when construction succeeds.
    class TransactionEnvelope
      EMPTY_METADATA = Ractor.make_shareable(
        {} # : Hash[untyped, untyped]
          .freeze
      )

      # @return [Object] transaction identifier
      # @return [Array<ChangeEvent>] events committed by the transaction
      # @return [String, nil] commit log sequence number
      # @return [Time, nil] commit timestamp
      # @return [EventMetadata] transaction metadata
      attr_reader :transaction_id, :events, :commit_lsn, :committed_at, :metadata

      # Build a transaction envelope.
      #
      # @param transaction_id [Object] upstream transaction identifier
      # @param events [Array<ChangeEvent>] committed events
      # @param commit_lsn [#to_s, nil] commit log sequence number
      # @param committed_at [Time, nil] commit timestamp
      # @param metadata [Hash, EventMetadata] transaction metadata
      def initialize(transaction_id:, events:, commit_lsn: nil, committed_at: nil, metadata: EMPTY_METADATA)
        @transaction_id = transaction_id
        @events = Ractor.make_shareable(events.freeze)
        @commit_lsn = commit_lsn&.to_s&.freeze
        @committed_at = committed_at
        @metadata = metadata.is_a?(EventMetadata) ? metadata : EventMetadata.new(metadata)
        Ractor.make_shareable(self)
      end

      # Whether the envelope has no events.
      #
      # @return [Boolean] true when the envelope has no events
      def empty? = events.empty?

      # Number of events in the envelope.
      #
      # @return [Integer] number of events in the envelope
      def size = events.size

      # Convert the transaction envelope into a Ractor-shareable hash.
      #
      # @return [Hash{String=>Object,nil}] Ractor-shareable transaction representation
      def to_h
        Ractor.make_shareable({
          'transaction_id' => transaction_id,
          'events' => events.map(&:to_h).freeze,
          'commit_lsn' => commit_lsn,
          'committed_at' => committed_at,
          'metadata' => metadata.to_h
        }.freeze)
      end
    end
  end
end
