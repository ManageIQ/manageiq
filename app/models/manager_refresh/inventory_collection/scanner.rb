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
          inventory_collections.each do |inventory_collection|
            inventory_collection.data_collection_finalized = true
            inventory_collection.scan!
          end
        end
      end
    end
  end
end
