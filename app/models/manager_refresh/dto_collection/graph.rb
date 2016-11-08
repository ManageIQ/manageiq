module ManagerRefresh
  class DtoCollection
    class Graph < ::ManagerRefresh::Graph
      def initialize(nodes)
        super(nodes)

        assert_dto_collections(nodes)
      end

      def build_directed_acyclic_graph!
        ################################################################################################################
        ## Description of an algorithm for building DAG
        ################################################################################################################
        # Terms:
        ##############
        # Fixed Edges - Are edges that cannot be removed from Graph, in our case these are edges caused by attributes
        #               that has to be present before saving the record. These are attributes that are part of the
        #               record identity (unique index of the DB record) and attributes validated for presence.
        # Feedback Edge Set - Is a set of edges that are causing a cycle in the graph
        # DAG - Directed Acyclic Graph
        #
        # Alghoritm:
        ##############
        # Building a Feedback Edge Set:
        # We will be building DAG from a Graph containing cycles, the algorithm is building a Feedback Edge Set by
        # adding edges to a DAG made from Fixed Edges, while checking if by adding a new edge we haven't created
        # a cycle in the graph.
        # Converting original graph to DAG:
        # Using the Feedback Edge Set, we remove the attributes causing cycles from the original graph. This way, we
        # get a DAG, but the DAG is missing attributes.
        # Using the Feedback Edge Set we create new Nodes, containing only removed attributes in a step before. These
        # nodes will be attached to Graph according to their dependencies. By saving these nodes, we will add the
        # missing relations.
        ################################################################################################################

        # Assert that Fixed edges do not have a cycle, we cannot move with fixed edges, so exception is thrown here
        assert_graph!(fixed_edges)

        # Collect Feedback Edge (Arc) Set
        feedback_edge_set = build_feedback_edge_set(edges, fixed_edges)

        # We will build a DAG using the Feedback Edge (Arc) Set. All edges from this set has to be removed, and the
        # edges are transferred to newly created nodes.
        convert_to_dag!(nodes, feedback_edge_set)

        # And assert again we really built a DAG
        assert_graph!(edges)

        self
      end

      private

      def assert_dto_collections(dto_collections)
        dto_collections.each do |dto_collection|
          unless dto_collection.kind_of? ::ManagerRefresh::DtoCollection
            raise "A ManagerRefresh::SaveInventory needs a DtoCollection object, it got: #{dto_collection.inspect}"
          end
        end
      end

      def convert_to_dag!(nodes, feedback_edge_set)
        new_nodes = []
        nodes.each do |dto_collection|
          feedback_dependencies = feedback_edge_set.select { |e| e.second == dto_collection }.map(&:first)
          attrs                 = dto_collection.dependency_attributes_for(feedback_dependencies)

          next if attrs.blank?

          new_dto_collection = dto_collection.clone

          # Add dto_collection as a dependency of the new_dto_collection, so we make sure it runs after
          # TODO(lsmola) add a nice dependency_attributes setter? It's used also in actualize_dendencies method
          new_dto_collection.dependency_attributes[:__feedback_edge_set_parent] = Set.new([dto_collection])
          new_nodes << new_dto_collection

          # TODO(lsmola) If we remove an attribute that was a dependency of another node, we need to move also the
          # dependency. So e.g. floating_ip depends on network_port's attribute vm, but we move that attribute to new
          # network_port dto_collection. We will need to move also the dependency to the new dto_collection.
          # So we have to go through all dependencies that loads a key, which is the moved attribute, I don't think we
          # even store that now.
          # So apart from dependency_attributes, we would store a dependency_attributes_keys, then if we find a
          # blacklisted_attribute in any dto_collection dependency_attribute_keys that depend on this dto collection,
          # we will also need to move this dependency. And if the result cause a cycle, we should repeat the build_dag
          # method, with a max depth 10. We should throw a warning maybe asking for simplifying the interconnections.

          dto_collection.blacklist_attributes!(attrs)
          new_dto_collection.whitelist_attributes!(attrs)
        end

        # Add the new DtoCollections to the list of nodes our our graph
        construct_graph!(nodes + new_nodes)
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
