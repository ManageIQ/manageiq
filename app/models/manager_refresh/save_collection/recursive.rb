module ManagerRefresh::SaveCollection
  class Recursive < ManagerRefresh::SaveCollection::Base
    class << self
      # Saves the passed InventoryCollection objects by recursively passing the graph
      #
      # @param ems [ExtManagementSystem] manager owning the inventory_collections
      # @param inventory_collections [Array<ManagerRefresh::InventoryCollection>] array of InventoryCollection objects
      #        for saving
      def save_collections(ems, inventory_collections)
        graph = ManagerRefresh::InventoryCollection::Graph.new(inventory_collections)
        graph.build_directed_acyclic_graph!

        graph.nodes.each do |inventory_collection|
          save_collection(ems, inventory_collection, [])
        end
      end

      private

      # Saves the one passed InventoryCollection object
      #
      # @param ems [ExtManagementSystem] manager owning the inventory_collections
      # @param inventory_collection [ManagerRefresh::InventoryCollection] InventoryCollection object for saving
      # @param traversed_collections [Array<ManagerRefresh::InventoryCollection>] array of traversed InventoryCollection
      #        objects, that we use for detecting possible cycle
      def save_collection(ems, inventory_collection, traversed_collections)
        unless inventory_collection.kind_of?(::ManagerRefresh::InventoryCollection)
          raise "A ManagerRefresh::SaveInventory needs a InventoryCollection object, it got: #{inventory_collection.inspect}"
        end

        return if inventory_collection.saved?

        traversed_collections << inventory_collection

        unless inventory_collection.saveable?
          inventory_collection.dependencies.each do |dependency|
            next if dependency.saved?
            if traversed_collections.include?(dependency)
              raise "Edge from #{inventory_collection} to #{dependency} creates a cycle"
            end
            save_collection(ems, dependency, traversed_collections)
          end
        end

        _log.debug("Saving #{inventory_collection} of size #{inventory_collection.size}")
        save_inventory_object_inventory(ems, inventory_collection)
      end
    end
  end
end
