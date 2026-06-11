# frozen_string_literal: true

module CDC
  module Core
    # Routes CDC work items to the appropriate handler.
    #
    # Router keeps the dispatch vocabulary in core while leaving execution
    # strategy to the caller. It can route single change events, transaction
    # envelopes, and arrays of events.
    class Router
      # @return [#process] handler for individual change events
      # @return [#process, nil] handler for transaction envelopes
      # @return [Observer] observer notified of dispatch events
      attr_reader :processor, :transaction_processor, :observer

      # Build a router.
      #
      # @param processor [#process] handler for change events
      # @param transaction_processor [#process, nil] handler for transaction envelopes
      # @param observer [Observer, nil] instrumentation observer
      def initialize(processor:, transaction_processor: nil, observer: NullObserver::INSTANCE)
        @processor = processor
        @transaction_processor = transaction_processor
        @observer = observer || NullObserver::INSTANCE
      end

      # Process a CDC work item.
      #
      # @param item [ChangeEvent, TransactionEnvelope, Array<ChangeEvent>] work item to route
      # @return [Object] value returned by the selected handler
      # @raise [UnsupportedWorkItemError] when the item cannot be routed
      def process(item)
        observer.dispatch_started(item)
        case item
        when ChangeEvent
          result = processor.process(item)
          observe_result(result)
          result
        when TransactionEnvelope
          route_transaction(item)
        when Array
          route_many(item)
        else
          raise UnsupportedWorkItemError, "unsupported CDC work item: #{item.class}"
        end
      end

      private

      # Route a transaction envelope to the configured transaction processor.
      #
      # @param transaction [TransactionEnvelope] transaction envelope to route
      # @return [Object] value returned by the transaction processor
      def route_transaction(transaction)
        return transaction_processor.process(transaction) if transaction_processor

        raise UnsupportedWorkItemError,
              "unsupported CDC work item: #{transaction.class} (transaction processor not configured)"
      end

      # Route many change events through the configured processor.
      #
      # @param items [Array] change events to route as a batch
      # @return [Object] batch processor result or array of per-event results
      def route_many(items)
        unless items.all?(ChangeEvent)
          raise UnsupportedWorkItemError, "unsupported CDC work item: Array(#{items.first.class})"
        end

        return processor.process_many(items) if processor.respond_to?(:process_many)

        items.map { |event| processor.process(event) }.freeze
      end

      def observe_result(result)
        return result unless result.is_a?(ProcessorResult)

        case result.status
        when :success
          observer.dispatch_succeeded(result)
        when :failure
          observer.dispatch_failed(result)
        when :skipped
          observer.dispatch_skipped(result)
        end

        result
      end
    end
  end
end
