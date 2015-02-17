module ManageiqForeman
  # like the WillPaginate collection
  class PagedResponse
    include Enumerable
    extend Forwardable

    attr_accessor :page
    attr_accessor :total
    attr_accessor :results

    # per_page, search, sort
    def initialize(json)
      if json.kind_of?(Hash) && json["results"]
        @results = json["results"]
        @total   = json["total"].to_i
        @page    = json["page"]
      else
        @results = json.kind_of?(Array) ? json : Array[json]
        @total = json.size
        @page  = 1
      end
    end

    def_delegators :results, :each, :[], :empty?, :size

    # modify the structure inline
    def map!(&block)
      self.results = results.map(&block)
      self
    end

    def ==(other)
      results == other.results
    end
  end
end
