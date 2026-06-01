# frozen_string_literal: true

module CDC
  module Core
    # Predicate object used to decide whether a pipeline should process an event.
    #
    # Filters are composable with #& and #|. A filter only matches when its
    # predicate returns true exactly, keeping accidental truthy values from
    # silently passing events through a pipeline.
    class Filter
      # Match every event.
      #
      # @return [Filter]
      def self.all = new { |_event| true }

      # Match events from a schema.
      #
      # @param name [#to_s] schema name
      # @return [Filter]
      def self.schema(name) = new { |event| event.schema == name.to_s }

      # Match events from a table regardless of schema.
      #
      # @param name [#to_s] table name
      # @return [Filter]
      def self.table(name) = new { |event| event.table == name.to_s }

      # Match events from a fully qualified schema.table name.
      #
      # @param name [#to_s] qualified table name
      # @return [Filter]
      def self.qualified_table(name) = new { |event| event.qualified_table_name == name.to_s }

      # Match events by operation.
      #
      # @param operation [#to_sym] CDC operation
      # @return [Filter]
      def self.operation(operation) = new { |event| event.operation == Operation.normalize(operation) }

      # Build a custom filter.
      #
      # @yieldparam event [ChangeEvent] event being tested
      # @yieldreturn [Boolean] true to match the event
      # @raise [ArgumentError] when no predicate block is provided
      def initialize(&predicate)
        raise ArgumentError, 'predicate block required' unless predicate

        @predicate = predicate
      end

      # Whether this filter matches an event.
      #
      # @param event [ChangeEvent] event to test
      # @return [Boolean]
      def match?(event)
        @predicate.call(event) == true
      end
      alias =~ match?

      # Compose this filter with another filter using logical AND.
      #
      # @param other [Filter] other filter
      # @return [Filter]
      def &(other)
        self.class.new { |event| match?(event) && other.match?(event) }
      end

      # Compose this filter with another filter using logical OR.
      #
      # @param other [Filter] other filter
      # @return [Filter]
      def |(other)
        self.class.new { |event| match?(event) || other.match?(event) }
      end
    end
  end
end
