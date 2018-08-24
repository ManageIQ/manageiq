module ManageIQ::Providers
  class Inventory
    require_nested :Collector
    require_nested :Parser
    require_nested :Persister

    attr_accessor :collector, :parsers, :persister

    # Based on the given provider/manager class, this returns correct parser class
    #
    # @param klass class of the Provider/Manager
    # @return [Class] Correct class name of the Parser
    def self.parser_class_for(klass)
      provider_module = ManageIQ::Providers::Inflector.provider_module(klass)
      "#{provider_module}::Inventory::Parser::#{klass.name.demodulize}".safe_constantize
    rescue ManageIQ::Providers::Inflector::ObjectNotNamespacedError => _err
      nil
    end

    # Based on the given provider/manager class, this returns correct persister class
    #
    # @param klass class of the Provider/Manager
    # @return [Class] Correct class name of the persister
    def self.persister_class_for(klass)
      provider_module = ManageIQ::Providers::Inflector.provider_module(klass)
      "#{provider_module}::Inventory::Persister::#{klass.name.demodulize}".safe_constantize
    rescue ManageIQ::Providers::Inflector::ObjectNotNamespacedError => _err
      nil
    end

    # @param persister [ManageIQ::Providers::Inventory::Persister] A Persister object
    # @param collector [ManageIQ::Providers::Inventory::Collector] A Collector object
    # @param parsers [ManageIQ::Providers::Inventory::Parser|Array] A Parser object or an array of
    #   ManageIQ::Providers::Inventory::Parser objects
    def initialize(persister, collector, parsers)
      @collector = collector
      @persister = persister
      @parsers   = parsers.kind_of?(Array) ? parsers : [parsers]
    end

    # Invokes all associated parsers storing parsed data into persister.inventory_collections
    #
    # @return [ManageIQ::Providers::Inventory::Persister] persister object, to allow chaining
    def parse
      parsers.each do |parser|
        parser.collector = collector
        parser.persister = persister
        parser.parse
      end

      persister
    end

    # Returns all InventoryCollections contained in persister
    #
    # @return [Array<ManagerRefresh::InventoryCollection>] List of InventoryCollections objects
    def inventory_collections
      parse.inventory_collections
    end
  end
end
