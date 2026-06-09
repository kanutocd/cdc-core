# frozen_string_literal: true

require 'test_helper'

class ProcessorChainTest < Minitest::Test
  class LoadUsersProcessor < CDC::Core::Processor
    def process(user_ids)
      users = user_ids.map { |id| { id: id, email: "user#{id}@example.test" } }
      CDC::Core::ProcessorResult.success(user_ids, value: users)
    end
  end

  class SendNotificationsProcessor < CDC::Core::Processor
    def process(users)
      CDC::Core::ProcessorResult.success(users, value: users.map { |user| user[:email] })
    end
  end

  class FalseyProcessor < CDC::Core::Processor
    def process(_input) = false # rubocop:disable Naming/PredicateMethod
  end

  class RaisingProcessor < CDC::Core::Processor
    def process(_input)
      raise 'boom'
    end
  end

  class RawTransformProcessor < CDC::Core::Processor
    def process(input)
      input.map(&:upcase)
    end
  end

  def test_feeds_each_successful_result_value_to_the_next_processor
    chain = CDC::Core::ProcessorChain.new([
                                            LoadUsersProcessor.new,
                                            SendNotificationsProcessor.new
                                          ])

    result = chain.process([1, 2])

    assert_predicate result, :success?
    assert_equal ['user1@example.test', 'user2@example.test'], result.value
  end

  def test_stops_when_a_processor_returns_a_skipped_result
    chain = CDC::Core::ProcessorChain.new([
                                            FalseyProcessor.new,
                                            SendNotificationsProcessor.new
                                          ])

    result = chain.process([1, 2])

    assert_predicate result, :skipped?
  end

  def test_wraps_exceptions_as_failure_results
    chain = CDC::Core::ProcessorChain.new([RaisingProcessor.new, SendNotificationsProcessor.new])

    result = chain.process([1, 2])

    assert_predicate result, :failure?
    assert_equal 'boom', result.failure_reason
    assert_equal 'ProcessorChainTest::RaisingProcessor', result.processor_name
  end

  def test_normalizes_raw_truthy_return_values_as_chain_values
    chain = CDC::Core::ProcessorChain.new([RawTransformProcessor.new])

    result = chain.process(%w[a b])

    assert_predicate result, :success?
    assert_equal %w[A B], result.value
  end

  def test_process_many_processes_inputs_in_order
    chain = CDC::Core::ProcessorChain.new([RawTransformProcessor.new])

    results = chain.process_many([%w[a], %w[b]])

    assert_equal [%w[A], %w[B]], results.map(&:value)
  end
end
