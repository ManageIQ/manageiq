module ManagerRefresh
  class Inventory
    require_nested :Collector
    require_nested :Parser
    require_nested :Persister

    attr_accessor :collector, :parsers, :persister

    def self.parser_class_for(klass)
      provider_module = ManageIQ::Providers::Inflector.provider_module(klass)
      "#{provider_module}::Inventory::Parser::#{klass.name.demodulize}".safe_constantize
    rescue ManageIQ::Providers::Inflector::ObjectNotNamespacedError => _err
      nil
    end

    def self.persister_class_for(klass)
      provider_module = ManageIQ::Providers::Inflector.provider_module(klass)
      "#{provider_module}::Inventory::Persister::#{klass.name.demodulize}".safe_constantize
    rescue ManageIQ::Providers::Inflector::ObjectNotNamespacedError => _err
      nil
    end

    # @param persister [ManagerRefresh::Inventory::Persister] A Persister object
    # @param collector [ManagerRefresh::Inventory::Collector] A Collector object
    # @param parsers [ManagerRefresh::Inventory::Parser|Array] A Parser object or an array of
    #   ManagerRefresh::Inventory::Parser objects
    def initialize(persister, collector, parsers)
      @collector = collector
      @persister = persister
      @parsers   = parsers.kind_of?(Array) ? parsers : [parsers]
    end

    # Invokes all associated parsers storing parsed data into persister.inventory_collections
    def parse
      parsers.each do |parser|
        parser.collector = collector
        parser.persister = persister
        parser.parse
      end

      persister
    end

    def inventory_collections
      parse.inventory_collections
    end
  end
end
