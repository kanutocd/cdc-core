# frozen_string_literal: true

module CDC
  module Core
    # Immutable grouping key for ordering-related dispatch.
    #
    # OrderingKey captures the scope plus the components that define a
    # particular ordered lane. It does not choose an execution strategy.
    class OrderingKey
      EMPTY_COMPONENTS = Ractor.make_shareable(
        {} # : Hash[untyped, untyped]
          .freeze
      )

      # @return [Symbol] ordering scope
      # @return [Hash{String=>Object}] normalized key components
      attr_reader :scope, :components

      # Build an ordering key.
      #
      # @param scope [#to_sym] ordering scope
      # @param components [Hash] key components
      def initialize(scope:, components: EMPTY_COMPONENTS)
        @scope = OrderingScope.normalize(scope)
        @components = EventMetadata.new(components).to_h
        Ractor.make_shareable(self)
      end

      # Whether the key has no components.
      #
      # @return [Boolean] true when the key has no components
      def empty? = components.empty?

      # Convert the key into a Ractor-shareable hash.
      #
      # @return [Hash{String=>Object}] Ractor-shareable ordering key representation
      def to_h
        Ractor.make_shareable({
          'scope' => scope,
          'components' => components
        }.freeze)
      end
    end
  end
end
