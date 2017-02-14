module ManagerRefresh
  class Inventory
    require_nested :Collector
    require_nested :Parser
    require_nested :Target

    attr_accessor :collector, :parsers, :target

    # @param target [ManagerRefresh::Inventory::Target] A target object
    # @param collector [ManagerRefresh::Inventory::Collector] A collector object
    # @param parsers [ManagerRefresh::Inventory::Parser|Array] A Parser object or an array of
    #   ManagerRefresh::Inventory::Parser objects
    def initialize(target, collector, parsers)
      @collector = collector
      @target    = target
      @parsers   = parsers.kind_of?(Array) ? parsers : [parsers]
    end

    def inventory_collections
      parsers.each do |parser|
        parser.collector = collector
        parser.target    = target
        parser.parse
      end

      target.inventory_collections
    end
  end
end
