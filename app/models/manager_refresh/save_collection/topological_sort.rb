module ManagerRefresh::SaveCollection
  class TopologicalSort
    extend ManagerRefresh::SaveCollection::Helper

    class << self
      def save_collections(ems, inventory_collections)
        graph = ManagerRefresh::InventoryCollection::Graph.new(inventory_collections.values)
        graph.build_directed_acyclic_graph!

        layers = ManagerRefresh::Graph::TopologicalSort.new(graph).topological_sort

        sorted_graph_log = "Topological sorting of manager #{ems.name} with ---nodes---:\n#{graph.nodes.join("\n")}\n"
        sorted_graph_log += "---edges---:\n#{graph.edges.map { |x| "<#{x.first}, #{x.last}>" }.join("\n")}\n"
        sorted_graph_log += "---resulted in these layers processable in parallel:"

        layers.each_with_index do |layer, index|
          sorted_graph_log += "\n----- Layer #{index} -----: \n#{layer.join("\n")}"
        end

        _log.info(sorted_graph_log)

        layers.each_with_index do |layer, index|
          _log.info("Saving manager #{ems.name} | Layer #{index}")
          layer.each do |inventory_collection|
            save_inventory_object_inventory(ems, inventory_collection) unless inventory_collection.saved?
          end
          _log.info("Saved manager #{ems.name} | Layer #{index}")
        end

        _log.info("All layers of manager #{ems.name} saved!")
      end
    end
  end
end
