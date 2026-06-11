# frozen_string_literal: true

module CDC
  module Core
    # Immutable representation of an event's position metadata.
    #
    # EventPosition is intentionally small and transport-agnostic. It captures
    # the position strategy plus the event fields that a runtime may use to
    # preserve ordering guarantees.
    class EventPosition
      # @return [Symbol] position strategy
      # @return [Object, nil] primary position value for the chosen strategy
      # @return [Object, nil] transaction identifier associated with the event
      # @return [Integer, nil] sequence number within a transaction or stream
      # @return [Time, nil] timestamp associated with the event
      attr_reader :strategy, :value, :transaction_id, :sequence_number, :occurred_at

      # Build an event position.
      #
      # @param strategy [#to_sym] position strategy
      # @param value [Object, nil] primary position value
      # @param transaction_id [Object, nil] transaction identifier
      # @param sequence_number [Integer, nil] sequence number
      # @param occurred_at [Time, nil] event timestamp
      def initialize(strategy:, value:, transaction_id: nil, sequence_number: nil, occurred_at: nil)
        @strategy = strategy.to_sym
        @value = value
        @transaction_id = transaction_id
        @sequence_number = sequence_number
        @occurred_at = occurred_at
        Ractor.make_shareable(self)
      end

      # Convert the position into a Ractor-shareable hash.
      #
      # @return [Hash{String=>Object,nil}] Ractor-shareable position representation
      def to_h
        Ractor.make_shareable({
          'strategy' => strategy,
          'value' => value,
          'transaction_id' => transaction_id,
          'sequence_number' => sequence_number,
          'occurred_at' => occurred_at
        }.freeze)
      end
    end
  end
end
