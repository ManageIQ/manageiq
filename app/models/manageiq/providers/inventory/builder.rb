class ManageIQ::Providers::Inventory::Builder
  class << self
    # Defines collector, persister and parser classes
    # and sends them to build inventory
    #
    # Builder for concrete provider has to define:
    # - `allowed_manager_types()`
    # - `default_manager_type()`
    #
    # Example:
    # - for ems == target == ManageIQ::Providers::Amazon::CloudManager
    #
    # collector: ManageIQ::Providers::Amazon::Inventory:Collector::CloudManager
    # parser:    ManageIQ::Providers::Amazon::Inventory:Parser::CloudManager
    # persister: ManageIQ::Providers::Amazon::Inventory:Persister::CloudManager
    def build_inventory(ems, target)
      case target
      when ManagerRefresh::TargetCollection
        build_target_collection_inventory(ems, target)
      else
        manager_type = ManageIQ::Providers::Inflector.manager_type(target)

        manager_type = default_manager_type unless allowed_manager_types.include?(manager_type)

        collector_type = "#{collector_class}::#{manager_type}Manager".safe_constantize
        persister_type = "#{persister_class}::#{manager_type}Manager".safe_constantize
        parser_type    = "#{parser_class}::#{manager_type}Manager".safe_constantize

        inventory(ems, target, collector_type, persister_type, [parser_type])
      end
    end

    def build_target_collection_inventory(ems, target)
      parsers = allowed_manager_types.collect do |manager_type|
        "#{parser_class}::#{manager_type}Manager".safe_constantize
      end

      inventory(
        ems,
        target,
        "#{collector_class}::TargetCollection".safe_constantize,
        "#{persister_class}::TargetCollection".safe_constantize,
        parsers
      )
    end

    protected

    def inventory(manager, raw_target, collector_class, persister_class, parsers_classes)
      collector = collector_class.new(manager, raw_target)
      persister = persister_class.new(manager, raw_target)

      inventory_class.new(
        persister,
        collector,
        parsers_classes.map(&:new)
      )
    end

    # Concrete provider has to define manager_types as Array
    #
    # Example:
    # %w(Cloud Network Infra)
    def allowed_manager_types
      raise NotImplementedError
    end

    # Default manager type chosen if refresh target's class doesn't contain
    # one of allowed_manager_types in name
    # Example: 'Cloud'
    def default_manager_type
      allowed_manager_types.first
    end

    # Automatically chooses inventory class based on builder class
    # Example:
    # - ManageIQ::Providers::Amazon::Builder => ManageIQ::Providers::Amazon::Inventory
    def inventory_class
      "#{ManageIQ::Providers::Inflector.provider_module(self)}::Inventory".constantize
    rescue
      ManageIQ::Providers::Inventory
    end

    def collector_class
      "#{inventory_class}::Collector".constantize
    rescue
      ManageIQ::Providers::Inventory::Collector
    end

    def parser_class
      "#{inventory_class}::Parser".constantize
    rescue
      ManageIQ::Providers::Inventory::Collector
    end

    def persister_class
      "#{inventory_class}::Persister".constantize
    rescue
      ManageIQ::Providers::Inventory::Collector
    end
  end
end
