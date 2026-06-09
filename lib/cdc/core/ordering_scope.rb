# frozen_string_literal: true

module CDC
  module Core
    # Canonical ordering scopes used by the CDC ecosystem.
    #
    # Ordering scopes describe how related events should be grouped when a
    # runtime or sink needs to preserve relative order.
    module OrderingScope
      # Preserve exact stream order.
      GLOBAL = :global
      # Preserve transaction order and boundaries.
      TRANSACTION = :transaction
      # Preserve ordering per relation/table.
      RELATION = :relation
      # Preserve ordering per primary key.
      PRIMARY_KEY = :primary_key
      # Do not impose a strict ordering guarantee.
      NONE = :none

      # All supported ordering scopes.
      SUPPORTED = Ractor.make_shareable([GLOBAL, TRANSACTION, RELATION, PRIMARY_KEY, NONE].freeze)

      module_function

      # Convert a scope-like value into a supported ordering scope symbol.
      #
      # @param scope [#to_sym] scope to normalize
      # @return [Symbol] one of SUPPORTED
      # @raise [InvalidOrderingScopeError] when the scope is not supported
      def normalize(scope)
        value = scope.to_sym
        return value if SUPPORTED.include?(value)

        raise InvalidOrderingScopeError, "unsupported CDC ordering scope: #{scope.inspect}"
      rescue NoMethodError
        raise InvalidOrderingScopeError, "unsupported CDC ordering scope: #{scope.inspect}"
      end

      # Check whether a scope-like value is supported.
      #
      # @param scope [#to_sym] scope to check
      # @return [Boolean] true when the value normalizes to a supported scope
      def supported?(scope)
        SUPPORTED.include?(scope.to_sym)
      rescue NoMethodError
        false
      end
    end
  end
end
