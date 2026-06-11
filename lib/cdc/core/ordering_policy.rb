# frozen_string_literal: true

module CDC
  module Core
    # Immutable description of how ordered CDC work should be grouped.
    #
    # OrderingPolicy defines the vocabulary for ordering guarantees without
    # performing any scheduling itself. Runtime layers can consume the policy to
    # route events into ordered lanes.
    class OrderingPolicy
      # Position strategies supported by the core contract.
      SUPPORTED_POSITIONS = Ractor.make_shareable(
        %i[commit_lsn transaction_id sequence_number occurred_at].freeze
      )

      # @return [Symbol] ordering scope
      # @return [Symbol] position strategy
      # @return [Boolean] whether transaction boundaries should be preserved
      attr_reader :scope, :position, :transaction_aware

      # Build an ordering policy.
      #
      # @param scope [#to_sym] ordering scope
      # @param position [#to_sym] position strategy
      # @param transaction_aware [Boolean] whether transaction boundaries matter
      def initialize(scope:, position: :commit_lsn, transaction_aware: true)
        @scope = OrderingScope.normalize(scope)
        @position = normalize_position(position)
        @transaction_aware = transaction_aware == true
        Ractor.make_shareable(self)
      end

      # Whether transaction boundaries should be preserved.
      #
      # @return [Boolean] true when transaction boundaries should be preserved
      def transaction_aware? = transaction_aware

      # Derive an ordering key for an event.
      #
      # @param event [ChangeEvent] event to classify
      # @return [OrderingKey, nil] ordering key for the event, or nil when no key applies
      def key_for(event)
        return nil if scope == OrderingScope::NONE

        components = key_components(event)
        return nil if components.nil?

        OrderingKey.new(scope: scope, components: components)
      end

      # Derive an event position for an event.
      #
      # @param event [ChangeEvent] event to classify
      # @return [EventPosition] position metadata for the event
      def position_for(event)
        EventPosition.new(
          strategy: position,
          value: event.public_send(position),
          transaction_id: event.transaction_id,
          sequence_number: event.sequence_number,
          occurred_at: event.occurred_at
        )
      end

      # Convert the policy into a Ractor-shareable hash.
      #
      # @return [Hash{String=>Object}] Ractor-shareable policy representation
      def to_h
        Ractor.make_shareable({
          'scope' => scope,
          'position' => position,
          'transaction_aware' => transaction_aware
        }.freeze)
      end

      private

      # Normalize the position strategy.
      #
      # @param position [#to_sym] position strategy
      # @return [Symbol] normalized supported position strategy
      def normalize_position(position)
        value = position.to_sym
        return value if SUPPORTED_POSITIONS.include?(value)

        raise InvalidOrderingPositionError, "unsupported CDC ordering position: #{position.inspect}"
      rescue NoMethodError
        raise InvalidOrderingPositionError, "unsupported CDC ordering position: #{position.inspect}"
      end

      # Build the components for the current scope.
      #
      # @param event [ChangeEvent] event to classify
      # @return [Hash, nil] key components for the current scope, or nil for an unknown internal scope
      def key_components(event)
        case scope
        when OrderingScope::GLOBAL
          {} # : Hash[untyped, untyped]
        when OrderingScope::TRANSACTION
          { transaction_id: event.transaction_id }
        when OrderingScope::RELATION
          { schema: event.schema, table: event.table }
        when OrderingScope::PRIMARY_KEY
          { schema: event.schema, table: event.table, primary_key: event.primary_key }
        end
      end
    end
  end
end
