module ManageIQ::Providers
  class Inventory
    require_nested :Collector
    require_nested :Parser
    require_nested :Persister

    attr_accessor :collector, :parsers, :persister

    # Entry point for building inventory
    def self.build(ems, target)
      collector = collector_class_for(ems, target).new(ems, target)
      persister = persister_class_for(ems, target).new(ems, target)
      new(
        persister,
        collector,
        parser_classes_for(ems, target).map(&:new)
      )
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

    # Based on the given provider/manager class, this returns correct collector class
    #
    # @param ems class of the Provider/Manager
    # @param target class of refresh's target
    # @return [Class] Correct class name of the collector
    def self.collector_class_for(ems, target = nil, manager_name = nil)
      target = ems if target.nil?
      class_for(ems, target, 'Collector', manager_name)
    end

    # Based on the given provider/manager class, this returns correct persister class
    #
    # @param ems class of the Provider/Manager
    # @param target class of refresh's target
    # @return [Class] Correct class name of the persister
    def self.persister_class_for(ems, target = nil, manager_name = nil)
      target = ems if target.nil?
      class_for(ems, target, 'Persister', manager_name)
    end

    # Based on the given provider/manager class, this returns correct parser class
    #
    # @param ems class of the Provider/Manager
    # @param target class of refresh's target
    # @return [Class] Correct class name of the Parser
    def self.parser_class_for(ems, target = nil, manager_name = nil)
      target = ems if target.nil?
      class_for(ems, target, 'Parser', manager_name)
    end

    # @param ems [ExtManagementSystem]
    # @param target [ExtManagementSystem, ManagerRefresh::TargetCollection]
    # @param type [String] 'Persister' | 'Collector' | 'Parser'
    # @param manager_name [String, nil] @see default_manager_name
    def self.class_for(ems, target, type, manager_name = nil)
      ems_class = ems.class == Class ? ems : ems.class
      provider_module = ManageIQ::Providers::Inflector.provider_module(ems_class)

      manager_name = parsed_manager_name(target) if manager_name.nil?

      klass = "#{provider_module}::Inventory::#{type}::#{manager_name}".safe_constantize
      # if class for given target doesn't exist, try to use class for default_manager (if defined)
      if klass.nil? && default_manager_name.present? && manager_name != default_manager_name
        klass = class_for(ems, target, type, default_manager_name)
      end
      klass
    rescue ManageIQ::Providers::Inflector::ObjectNotNamespacedError => _err
      nil
    end

    # Fallback manager name when persister/parser/collector not determined from refreshes' target
    # @return [String, nil] i.e. 'CloudManager'
    def self.default_manager_name
      nil
    end

    # Last part of persister/parser/collector class name
    # For example 'CloudManager' or 'StorageManager::Ebs'
    def self.parsed_manager_name(target)
      case target
      when ManagerRefresh::TargetCollection
        'TargetCollection'
      else
        klass = target.class == Class ? target : target.class
        suffix_arr = klass.name.split('::') - ManageIQ::Providers::Inflector.provider_module(klass).name.split("::")
        suffix_arr.join('::')
      end
    rescue ManageIQ::Providers::Inflector::ObjectNotNamespacedError => _err
      nil
    end

    # Multiple parser classes
    # Can be implemented in subclass when custom set needed (mainly for TargetCollection)
    def self.parser_classes_for(ems, target)
      [parser_class_for(ems, target)]
    end
  end
end
