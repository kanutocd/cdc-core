# frozen_string_literal: true

require 'cdc/core'

class PrintProcessor < CDC::Core::Processor
  ractor_safe!

  def process(event)
    puts "#{event.operation.upcase} #{event.qualified_table_name}"
    CDC::Core::ProcessorResult.success(event)
  end
end

event = CDC::Core::ChangeEvent.new(
  operation: :update,
  schema: 'public',
  table: 'users',
  old_values: { 'email' => 'old@example.com' },
  new_values: { 'email' => 'new@example.com' },
  primary_key: { 'id' => 7 },
  transaction_id: 789
)

pipeline = CDC::Core::Pipeline.new(
  processor: PrintProcessor.new,
  filters: [CDC::Core::Filter.table('users')]
)

pipeline.process(event)
