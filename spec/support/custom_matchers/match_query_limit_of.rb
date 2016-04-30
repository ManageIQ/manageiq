# Derived from code found in http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed
#
# Example usage:
#   expect { MyModel.do_the_queries }.to match_query_limit_of(5)

RSpec::Matchers.define :match_query_limit_of do |expected|
  match do |block|
    @query_count = QueryCounter.count(&block)
    @query_count == expected
  end

  failure_message do |_actual|
    "Expected #{expected} queries, got #{@query_count}"
  end

  description do
    "expect the block to execute certain number of queries"
  end

  supports_block_expectations
end
