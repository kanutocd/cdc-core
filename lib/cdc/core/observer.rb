# frozen_string_literal: true

module CDC
  module Core
    # Observer interface for CDC runtime instrumentation.
    #
    # Observers receive lifecycle and result notifications from core runtime
    # objects. The default implementation is a no-op so callers can opt in
    # without taking a dependency on a metrics backend.
    class Observer
      # Canonical metric names emitted by core runtime hooks.
      METRIC_NAMES = Ractor.make_shareable({
        dispatch_started: 'cdc_core.dispatch.started',
        dispatch_succeeded: 'cdc_core.dispatch.succeeded',
        dispatch_failed: 'cdc_core.dispatch.failed',
        dispatch_skipped: 'cdc_core.dispatch.skipped'
      }.freeze)

      # Build a canonical metric tag set for a CDC work item or result.
      #
      # @param payload [ChangeEvent, TransactionEnvelope, ProcessorResult, Array] payload to describe
      # @return [Hash{String=>Object}] canonical metric tags for the payload
      def self.metric_tags(payload)
        tags = {} # : Hash[String, untyped]
        case payload
        when ChangeEvent
          tags.merge!(change_event_metric_tags(payload))
        when TransactionEnvelope
          tags.merge!(transaction_envelope_metric_tags(payload))
        when ProcessorResult
          tags.merge!(processor_result_metric_tags(payload))
        when Array
          tags.merge!(batch_metric_tags(payload))
        else
          tags['kind'] = payload.class.name
        end

        Ractor.make_shareable(tags.freeze)
      end

      # Canonical metric name for the start hook.
      #
      # @return [String] canonical dispatch-started metric name
      def self.started_metric_name = METRIC_NAMES.fetch(:dispatch_started)

      # Canonical metric name for the success hook.
      #
      # @return [String] canonical dispatch-succeeded metric name
      def self.succeeded_metric_name = METRIC_NAMES.fetch(:dispatch_succeeded)

      # Canonical metric name for the failure hook.
      #
      # @return [String] canonical dispatch-failed metric name
      def self.failed_metric_name = METRIC_NAMES.fetch(:dispatch_failed)

      # Canonical metric name for the skip hook.
      #
      # @return [String] canonical dispatch-skipped metric name
      def self.skipped_metric_name = METRIC_NAMES.fetch(:dispatch_skipped)

      # Called before a work item is dispatched.
      #
      # @param _event [ChangeEvent, TransactionEnvelope, Array] work item about to be dispatched
      # @return [void] no return value
      def dispatch_started(_event); end

      # Called after a work item is processed successfully.
      #
      # @param _result [ProcessorResult, Array<ProcessorResult>] successful processor result or results
      # @return [void] no return value
      def dispatch_succeeded(_result); end

      # Called after a work item fails.
      #
      # @param _result [ProcessorResult] failed processor result
      # @return [void] no return value
      def dispatch_failed(_result); end

      # Called when a work item is filtered or skipped.
      #
      # @param _result [ProcessorResult] skipped processor result
      # @return [void] no return value
      def dispatch_skipped(_result); end

      private_class_method def self.change_event_metric_tags(event)
        {
          'kind' => 'change_event',
          'operation' => event.operation,
          'schema' => event.schema,
          'table' => event.table
        }.tap do |tags|
          tags['transaction_id'] = event.transaction_id if event.transaction_id
        end
      end

      private_class_method def self.transaction_envelope_metric_tags(transaction)
        {
          'kind' => 'transaction_envelope',
          'transaction_id' => transaction.transaction_id,
          'size' => transaction.size
        }
      end

      private_class_method def self.processor_result_metric_tags(result)
        tags = {
          'kind' => 'processor_result',
          'status' => result.status,
          'retryable' => result.retryable?
        } # : Hash[String, untyped]

        processor_name = result.processor_name
        tags['processor'] = processor_name if processor_name

        failure_reason = result.failure_reason
        tags['failure_reason'] = failure_reason if result.failure? && failure_reason

        tags
      end

      private_class_method def self.batch_metric_tags(batch)
        {
          'kind' => 'batch',
          'size' => batch.size
        }
      end
    end
  end
end
