module ManagerRefresh
  class InventoryCollection
    class Scanner
      class << self
        # Scanning inventory_collections for dependencies and references, storing the results in the inventory_collections
        # themselves. Dependencies are needed for building a graph, references are needed for effective DB querying, where
        # we can load all referenced objects of some InventoryCollection by one DB query.
        #
        # @param inventory_collections [Array] Array fo
        def scan!(inventory_collections)
          indexed_inventory_collections = inventory_collections.index_by(&:name)

          inventory_collections.each do |inventory_collection|
            inventory_collection.data_collection_finalized = true
            inventory_collection.scan!(indexed_inventory_collections)
          end

          inventory_collections.each do |inventory_collection|
            inventory_collection.dependencies.each do |dependency|
              dependency.dependees << inventory_collection
            end
          end
        end
      end
    end
  end
end
