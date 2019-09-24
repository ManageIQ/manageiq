# Derived from code found in http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed
#
# Example usage:
#   expect { MyModel.do_the_queries }.to_not exceed_query_limit(2)

RSpec::Matchers.define :exceed_query_limit do |expected|
  match do |block|
    @query_count = Spec::Support::QueryCounter.count(&block)
    @query_count > expected
  end

  failure_message_when_negated do |_actual|
    "Expected maximum #{expected} queries, got #{@query_count}"
  end

  supports_block_expectations
end
