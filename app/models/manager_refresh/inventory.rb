module ManagerRefresh
  class Inventory
    require_nested :Collector
    require_nested :Parser
    require_nested :Persister

    attr_accessor :collector, :parsers, :persister

    # @param persister [ManagerRefresh::Inventory::Persister] A Persister object
    # @param collector [ManagerRefresh::Inventory::Collector] A Collector object
    # @param parsers [ManagerRefresh::Inventory::Parser|Array] A Parser object or an array of
    #   ManagerRefresh::Inventory::Parser objects
    def initialize(persister, collector, parsers)
      @collector = collector
      @persister = persister
      @parsers   = parsers.kind_of?(Array) ? parsers : [parsers]
    end

    def inventory_collections
      parsers.each do |parser|
        parser.collector = collector
        parser.persister = persister
        parser.parse
      end

      persister.inventory_collections
    end
  end
end
