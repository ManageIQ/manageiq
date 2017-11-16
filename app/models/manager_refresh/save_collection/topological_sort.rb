module ManagerRefresh::SaveCollection
  class TopologicalSort < ManagerRefresh::SaveCollection::Base
    class << self
      def save_collections(ems, inventory_collections)
        graph = ManagerRefresh::InventoryCollection::Graph.new(inventory_collections)
        graph.build_directed_acyclic_graph!

        layers = ManagerRefresh::Graph::TopologicalSort.new(graph).topological_sort

        _log.debug("Saving manager #{ems.name}...")

        sorted_graph_log = "Topological sorting of manager #{ems.name} resulted in these layers processable in parallel:\n"
        sorted_graph_log += graph.to_graphviz(:layers => layers)
        _log.debug(sorted_graph_log)

        layers.each_with_index do |layer, index|
          _log.debug("Saving manager #{ems.name} | Layer #{index}")
          layer.each do |inventory_collection|
            save_inventory_object_inventory(ems, inventory_collection) unless inventory_collection.saved?
          end
          _log.debug("Saved manager #{ems.name} | Layer #{index}")
        end

        _log.debug("Saving manager #{ems.name}...Complete")
      end
    end
  end
end
