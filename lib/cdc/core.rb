# frozen_string_literal: true

require_relative 'core/version'
require_relative 'core/errors'
require_relative 'core/operation'
require_relative 'core/column_change'
require_relative 'core/event_metadata'
require_relative 'core/change_event'
require_relative 'core/transaction_envelope'
require_relative 'core/processor_result'
require_relative 'core/processor'
require_relative 'core/composite_processor'
require_relative 'core/filter'
require_relative 'core/pipeline'

module CDC
  # Database-agnostic Change Data Capture domain primitives.
  module Core
  end
end
