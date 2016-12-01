module ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies
  class Api4 < ManageIQ::Providers::Redhat::InfraManager::Refresh::Refresher
    attr_reader :ems

    def inventory_from_rhv(ems)
      @ems = ems
      InventoryWrapper.new(old_inventory: super, ems: ems)
    end

    class InventoryWrapper
      attr_reader :old_inventory
      attr_reader :ems

      def initialize(args)
        @ems = args[:ems]
        @old_inventory = args[:old_inventory]
      end

      def refresh
        res = old_inventory.refresh
        res[:cluster] = collect_clusters
        res[:storage] = collect_storages
        res
      end

      def collect_clusters
        clusters = @ems.with_provider_connection(:version => 4) do |connection|
          connection.system_service.clusters_service.list
        end
        clusters.collect {|c| BracketNotationDecorator.new(c) }
      end

      def collect_storages
        storagess = @ems.with_provider_connection(:version => 4) do |connection|
          connection.system_service.storage_domains_service.list
        end
        storagess.collect {|s| BracketNotationDecorator.new(s) }
      end

      def api
        old_inventory.api
      end

      def service
        old_inventory.service
      end
    end
  end

  class BracketNotationDecorator < SimpleDelegator
    ALLOWED_METHODS = ["id", "name", "href"]

    def initialize(obj)
      @obj = obj
      super
    end

    def [](key)
      return super unless ALLOWED_METHODS.include?(key.to_s)
      @obj.send(key)
    end

    def attributes
      instance_values
    end
  end
end
