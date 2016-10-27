module ManagerRefresh
  class DtoCollection
    class Graph < ::ManagerRefresh::Graph
      def initialize(nodes)
        super(nodes)

        assert_dto_collections(nodes)
      end

      def build_directed_acyclic_graph!
        # Obtain edges and fixed edges using dependencies of DtoCollections
        edges, fixed_edges = build_edges(nodes)

        # Assert that Fixed edges do not have a cycle, we cannot move with fixed edges, so exception is thrown here
        assert_graph!(fixed_edges)

        # Collect Feedback Edge (Arc) Set
        feedback_edge_set = build_feedback_edge_set(edges, fixed_edges)

        # We will build a DAG using the Feedback Edge (Arc) Set. All edges from this set has to be removed, and the
        # edges are transferred to newly created nodes.
        convert_to_dag!(nodes, feedback_edge_set)

        # Now rebuild the graph into DAG, storing right nodes and edges
        self.edges, _ = build_edges(nodes)

        # And assert again we really built a DAG
        assert_graph!(self.edges)

        self
      end

      private

      def assert_dto_collections(dto_collections)
        dto_collections.each do |dto_collection|
          unless dto_collection.is_a? ::ManagerRefresh::DtoCollection
            raise "A ManagerRefresh::SaveInventory needs a DtoCollection object, it got: #{dto_collection.inspect}"
          end
        end
      end

      def convert_to_dag!(nodes, feedback_edge_set)
        nodes.each do |dto_collection|
          feedback_dependencies = feedback_edge_set.select { |e| e.second == dto_collection }.map(&:first)
          attrs                 = dto_collection.dependency_attributes_for(feedback_dependencies)

          # Todo first dup the dto_collection, then blacklist it in original and whitelist it in the second one
          unless attrs.blank?
            dto_collection.blacklist_attributes!(attrs)
          end
        end
      end

      def build_edges(dto_collections)
        edges       = []
        fixed_edges = []
        dto_collections.each do |dto_collection|
          dto_collection.dependencies.each do |dependency|
            fixed_edges << [dependency, dto_collection] if dto_collection.fixed_dependencies.include?(dependency)
            edges << [dependency, dto_collection]
          end
        end
        return edges, fixed_edges
      end
    end
  end
end
