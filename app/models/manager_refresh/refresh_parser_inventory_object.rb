module ManagerRefresh
  class RefreshParserInventoryObject
    attr_reader :inventory, :inventory_collections

    def initialize(inventory)
      @inventory             = inventory
      @inventory_collections = inventory.inventory_collections
    end

    def process_inventory_collection(collection, key)
      (collection || []).each do |item|
        new_result = yield(item)
        next if new_result.blank?

        raise "InventoryCollection #{key} must be defined" unless inventory_collections[key]

        inventory_object = inventory_collections[key].new_inventory_object(new_result)
        inventory_collections[key] << inventory_object
      end
    end

    class << self
      def ems_inv_to_hashes(inventory)
        new(inventory).ems_inv_to_hashes
      end
    end
  end
end
