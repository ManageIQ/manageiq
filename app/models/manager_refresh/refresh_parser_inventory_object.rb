module ManagerRefresh
  class RefreshParserInventoryObject
    def initialize(ems, options = nil)
      @ems     = ems
      @options = options || {}
      @data    = {:_inventory_collection => true}
    end

    def process_inventory_collection(collection, key)
      collection.each do |item|
        new_result = yield(item)
        next if new_result.blank?

        inventory_object = @data[key].new_inventory_object(new_result)
        @data[key] << inventory_object
      end
    end

    def add_inventory_collection(model_class, association, manager_ref = nil)
      delete_method = model_class.new.respond_to?(:disconnect_inv) ? :disconnect_inv : nil

      @data[association] = ::ManagerRefresh::InventoryCollection.new(model_class,
                                                                     :parent        => @ems,
                                                                     :association   => association,
                                                                     :manager_ref   => manager_ref,
                                                                     :delete_method => delete_method)
    end

    def add_cloud_manager_db_cached_inventory_object(model_class, association, manager_ref = nil)
      @data[association] = ::ManagerRefresh::InventoryCollection.new(model_class,
                                                                     :parent      => @ems.parent_manager,
                                                                     :association => association,
                                                                     :manager_ref => manager_ref,
                                                                     :strategy    => :local_db_cache_all)
    end

    class << self
      def ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end
    end
  end
end
