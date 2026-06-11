# frozen_string_literal: true

module CDC
  module Core
    # Immutable metadata container for CDC domain objects.
    #
    # Metadata keys are normalized to frozen strings. Nested hashes and arrays
    # are recursively converted into Ractor-shareable objects. Values that Ruby
    # cannot make shareable are stored as frozen #inspect strings.
    class EventMetadata
      EMPTY_DATA = Ractor.make_shareable(
        {} # : Hash[untyped, untyped]
          .freeze
      )

      # @return [Hash{String=>Object}] normalized metadata
      attr_reader :data

      # Build metadata from a hash-like structure.
      #
      # @param data [Hash] metadata values
      def initialize(data = EMPTY_DATA)
        @data = deep_shareable_hash(data)
        Ractor.make_shareable(self)
      end

      # Fetch a metadata value by string or symbol key.
      #
      # @param key [String, Symbol] metadata key
      # @return [Object, nil]
      def [](key)
        string_key = key.to_s
        return data[string_key] if data.key?(string_key)

        data[key]
      end

      # Return the normalized Ractor-shareable hash.
      #
      # @return [Hash{String=>Object}]
      def to_h
        data
      end

      private

      # Recursively normalize and freeze a hash.
      #
      # @param hash [Hash]
      # @return [Hash{String=>Object}]
      def deep_shareable_hash(hash)
        converted = hash.each_with_object(
          {} # : Hash[String, untyped]
        ) do |(key, value), memo|
          memo[normalize_key(key)] = normalize_value(value)
        end
        Ractor.make_shareable(converted.freeze)
      end

      # Normalize metadata keys to frozen strings.
      #
      # @param key [Object]
      # @return [String]
      def normalize_key(key)
        key.to_s.freeze
      end

      # Normalize a metadata value into a shareable representation.
      #
      # @param value [Object]
      # @return [Object]
      def normalize_value(value)
        case value
        when Hash
          deep_shareable_hash(value)
        when Array
          Ractor.make_shareable(value.map { |item| normalize_value(item) }.freeze)
        else
          Ractor.make_shareable(value)
        end
      rescue Ractor::Error
        Ractor.make_shareable(value.inspect.freeze)
      end
    end
  end
end
