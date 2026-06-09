# frozen_string_literal: true

require_relative 'core/version'
require_relative 'core/errors'
require_relative 'core/operation'
require_relative 'core/column_change'
require_relative 'core/event_metadata'
require_relative 'core/ordering_scope'
require_relative 'core/event_position'
require_relative 'core/ordering_key'
require_relative 'core/ordering_policy'
require_relative 'core/change_event'
require_relative 'core/transaction_envelope'
require_relative 'core/source_adapter'
require_relative 'core/processor_result'
require_relative 'core/processor'
require_relative 'core/composite_processor'
require_relative 'core/processor_chain'
require_relative 'core/observer'
require_relative 'core/null_observer'
require_relative 'core/filter'
require_relative 'core/router'
require_relative 'core/pipeline'

# Top-level namespace for Change Data Capture libraries.
module CDC
  # Database-agnostic Change Data Capture domain primitives.
  #
  # CDC::Core intentionally contains only lightweight runtime abstractions:
  # events, metadata, source adapters, processors, filters, pipelines, and
  # processor results. Transport, PostgreSQL protocol parsing, and value
  # decoding live in sibling gems so this layer can remain independently
  # useful.
  module Core
  end
end
