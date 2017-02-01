module ManagerRefresh
  class Inventory
    require_nested :Collector
    require_nested :Parser
    require_nested :Target

    attr_accessor :collector
    attr_accessor :target
    attr_accessor :parser

    def initialize(target, collector, parser)
      @collector = collector
      @target    = target
      @parser    = parser
    end

    def inventory_collections
      parser.collector = collector
      parser.target = target
      parser.parse
      target.inventory_collections
    end
  end
end
