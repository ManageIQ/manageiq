module ManagerRefresh
  class Graph
    class TopologicalSort
      attr_reader :graph

      # @param graph [ManagerRefresh::Graph] graph object we want to sort
      def initialize(graph)
        @graph = graph
      end

        ################################################################################################################
        # Topological sort of the graph of the DTO collections to find the right order of saving DTO collections and
        # identify what DTO collections can be saved in parallel.
        # Does not mutate graph.
        #
        # @return [Array<Array>] Array of arrays(layers) of InventoryCollection objects
        ################################################################################################################
        # The expected input here is the directed acyclic Graph G (inventory_collections), consisting of Vertices(Nodes) V and
        # Edges E:
        # G = (V, E)
        #
        # The directed edge is defined as (u, v), where u is the dependency of v, i.e. arrow comes from u to v:
        # (u, v) ∈ E and  u,v ∈ V
        #
        # S0 is a layer that has no dependencies:
        # S0 = { v ∈ V ∣ ∀u ∈ V.(u,v) ∉ E}
        #
        # Si+1 is a layer whose dependencies are in the sum of the previous layers from i to 0, cannot write
        # mathematical sum using U in text editor, so there is an alternative format using _(sum)
        # Si+1 = { v ∈ V ∣ ∀u ∈ V.(u,v) ∈ E → u ∈ _(sum(S0..Si))_ }
        #
        # Then each Si can have their Vertices(DTO collections) processed in parallel. This algorithm cannot
        # identify independent sub-graphs inside of the layers Si, so we can make the processing even more effective.
        ################################################################################################################
      def topological_sort
        nodes          = graph.nodes.dup
        edges          = graph.edges
        sets           = []
        i              = 0
        sets[0], nodes = nodes.partition { |v| !edges.detect { |e| e.second == v } }

        max_depth = 1000
        while nodes.present?
          i         += 1
          max_depth -= 1
          if max_depth <= 0
            message = "Max depth reached while doing topological sort, your graph probably contains a cycle"
            $log.error("#{message}:\n#{graph.to_graphviz}")
            raise "#{message} (see log)"
          end

          set, nodes = nodes.partition { |v| edges.select { |e| e.second == v }.all? { |e| sets.flatten.include?(e.first) } }
          if set.blank?
            message = "Blank dependency set while doing topological sort, your graph probably contains a cycle"
            $log.error("#{message}:\n#{graph.to_graphviz}")
            raise "#{message} (see log)"
          end

          sets[i] = set
        end

        sets
      end
    end
  end
end
