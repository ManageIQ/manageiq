module Api
  class QueryCounts
    attr_reader :count, :subcount, :subquery_count

    def initialize(count, subcount = nil, subquery_count = nil)
      @count = count
      @subcount = subcount
      @subquery_count = subquery_count
    end

    def counts
      {
        :count          => count,
        :subcount       => subcount,
        :subquery_count => subquery_count
      }.compact
    end
  end
end
