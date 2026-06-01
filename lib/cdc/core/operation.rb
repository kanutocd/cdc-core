# frozen_string_literal: true

module CDC
  module Core
    # Canonical CDC operation names.
    #
    # Operations are represented as symbols to keep event objects small,
    # immutable, and easy to compare. Use .normalize when accepting user input
    # and .supported? when validating optional values.
    module Operation
      # Insert row operation.
      INSERT = :insert
      # Update row operation.
      UPDATE = :update
      # Delete row operation.
      DELETE = :delete
      # Truncate table operation.
      TRUNCATE = :truncate
      # Logical replication message operation.
      MESSAGE = :message
      # All operation names currently recognized by cdc-core.
      SUPPORTED = Ractor.make_shareable([INSERT, UPDATE, DELETE, TRUNCATE, MESSAGE].freeze)
      # Minimal row-change operations used by the initial runtime surface.
      MVP = Ractor.make_shareable([INSERT, UPDATE, DELETE].freeze)

      module_function

      # Convert an operation-like value into a supported operation symbol.
      #
      # @param operation [#to_sym] value to normalize
      # @return [Symbol] one of SUPPORTED
      # @raise [InvalidOperationError] when the operation is not supported
      def normalize(operation)
        value = operation.to_sym
        return value if SUPPORTED.include?(value)

        raise InvalidOperationError, "unsupported CDC operation: #{operation.inspect}"
      end

      # Check whether an operation-like value is supported.
      #
      # @param operation [#to_sym] value to check
      # @return [Boolean] true when the value normalizes to a supported operation
      def supported?(operation)
        SUPPORTED.include?(operation.to_sym)
      rescue NoMethodError
        false
      end
    end
  end
end
