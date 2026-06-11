# frozen_string_literal: true

module CDC
  module Core
    # Immutable representation of one logical database change.
    #
    # ChangeEvent is the core data structure passed through filters, pipelines,
    # and processors. It is database-agnostic but carries common CDC fields such
    # as operation, schema, table, before/after values, primary key, LSN, and
    # metadata.
    class ChangeEvent
      EMPTY_METADATA = Ractor.make_shareable(
        {} # : Hash[untyped, untyped]
          .freeze
      )

      # @return [Symbol] normalized CDC operation
      # @return [String] database schema name
      # @return [String] database table name
      # @return [Hash, nil] values before the change
      # @return [Hash, nil] values after the change
      # @return [Hash, nil] primary key values for the changed row
      # @return [Object, nil] transaction identifier from the upstream source
      # @return [String, nil] commit log sequence number
      # @return [Integer, nil] event sequence within a transaction or stream
      # @return [Time, nil] timestamp associated with the event
      # @return [EventMetadata] additional normalized metadata
      attr_reader :operation, :schema, :table, :old_values, :new_values, :primary_key,
                  :transaction_id, :commit_lsn, :sequence_number, :occurred_at, :metadata

      # Build a change event.
      #
      # @param operation [#to_sym] CDC operation
      # @param schema [#to_s] schema name
      # @param table [#to_s] table name
      # @param old_values [Hash, nil] values before the change
      # @param new_values [Hash, nil] values after the change
      # @param primary_key [Hash, nil] primary key values
      # @param transaction_id [Object, nil] source transaction identifier
      # @param commit_lsn [#to_s, nil] commit log sequence number
      # @param sequence_number [Integer, nil] event sequence number
      # @param occurred_at [Time, nil] event timestamp
      # @param metadata [Hash, EventMetadata] additional event metadata
      def initialize(operation:, schema:, table:, old_values: nil, new_values: nil, primary_key: nil,
                     transaction_id: nil, commit_lsn: nil, sequence_number: nil, occurred_at: nil,
                     metadata: EMPTY_METADATA)
        @operation = Operation.normalize(operation)
        @schema = String(schema).freeze
        @table = String(table).freeze
        @old_values = freeze_hash_or_nil(old_values)
        @new_values = freeze_hash_or_nil(new_values)
        @primary_key = freeze_hash_or_nil(primary_key)
        @transaction_id = transaction_id
        @commit_lsn = commit_lsn&.to_s&.freeze
        @sequence_number = sequence_number
        @occurred_at = occurred_at
        @metadata = metadata.is_a?(EventMetadata) ? metadata : EventMetadata.new(metadata)
        Ractor.make_shareable(self)
      end

      # @return [Boolean] true for insert events
      def insert? = operation == Operation::INSERT

      # @return [Boolean] true for update events
      def update? = operation == Operation::UPDATE

      # @return [Boolean] true for delete events
      def delete? = operation == Operation::DELETE

      # Fully qualified table name in schema.table form.
      #
      # @return [String]
      def qualified_table_name = "#{schema}.#{table}".freeze

      # Compute changed columns by comparing old and new values.
      #
      # Columns with equal old and new values are omitted. Insert and delete
      # events can pass nil for one side; missing values are represented as nil.
      #
      # @return [Array<ColumnChange>] Ractor-shareable changed columns
      def changes
        keys = ((old_values || {}).keys | (new_values || {}).keys)
        keys.filter_map do |key|
          change = ColumnChange.new(name: key, old_value: old_values&.[](key), new_value: new_values&.[](key))
          change if change.changed?
        end.then { |items| Ractor.make_shareable(items.freeze) }
      end

      # Convert the event into a Ractor-shareable hash.
      #
      # @return [Hash{String=>Object,nil}]
      def to_h
        Ractor.make_shareable({
          'operation' => operation,
          'schema' => schema,
          'table' => table,
          'old_values' => old_values,
          'new_values' => new_values,
          'primary_key' => primary_key,
          'transaction_id' => transaction_id,
          'commit_lsn' => commit_lsn,
          'sequence_number' => sequence_number,
          'occurred_at' => occurred_at,
          'metadata' => metadata.to_h
        }.freeze)
      end

      private

      # Convert a hash into immutable EventMetadata storage, preserving nil.
      #
      # @param hash [Hash, nil]
      # @return [Hash, nil]
      def freeze_hash_or_nil(hash)
        return nil if hash.nil?

        EventMetadata.new(hash).to_h
      end
    end
  end
end
