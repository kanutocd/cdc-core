# frozen_string_literal: true

module CDC
  module Core
    # Represents a single column-level value change.
    #
    # ColumnChange is immutable and Ractor-shareable. Values that cannot be made
    # shareable by Ruby are represented by their frozen #inspect string so the
    # enclosing event can still cross Ractor boundaries safely.
    class ColumnChange
      # @return [String] column name
      # @return [Object, nil] value before the change
      # @return [Object, nil] value after the change
      attr_reader :name, :old_value, :new_value

      # Build a column-level change object.
      #
      # @param name [#to_s] column name
      # @param old_value [Object, nil] previous value
      # @param new_value [Object, nil] new value
      def initialize(name:, old_value:, new_value:)
        @name = String(name).freeze
        @old_value = make_value_shareable(old_value)
        @new_value = make_value_shareable(new_value)
        Ractor.make_shareable(self)
      end

      # Whether the old and new values differ.
      #
      # @return [Boolean]
      def changed?
        old_value != new_value
      end

      # Convert the change into a Ractor-shareable hash.
      #
      # @return [Hash{String=>Object,nil}]
      def to_h
        Ractor.make_shareable({ 'name' => name, 'old_value' => old_value, 'new_value' => new_value }.freeze)
      end

      private

      # Convert a value into a Ractor-shareable representation.
      #
      # @param value [Object, nil]
      # @return [Object, String, nil]
      def make_value_shareable(value)
        Ractor.make_shareable(value)
      rescue Ractor::Error
        Ractor.make_shareable(value.inspect.freeze)
      end
    end
  end
end
