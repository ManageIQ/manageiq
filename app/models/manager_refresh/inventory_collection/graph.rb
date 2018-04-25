module ManagerRefresh
  class InventoryCollection
    class Graph < ::ManagerRefresh::Graph
      # @param nodes [Array<ManagerRefresh::InventoryCollection>] List of Inventory collection nodes
      def initialize(nodes)
        super(nodes)

        assert_inventory_collections(nodes)
      end

      # Turns the graph into DAG (Directed Acyclic Graph)
      #
      # @return [ManagerRefresh::InventoryCollection::Graph] Graph object modified into DAG
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

        # And assert again we've really built a DAG
        # TODO(lsmola) And if the result causes a cycle, we should repeat the build_dag method, with a max
        # depth 10. We should throw a warning maybe asking for simplifying the interconnections in the models.
        assert_graph!(edges)

        self.nodes = sort_nodes(nodes)

        self
      end

      private

      # Sort the nodes putting child nodes as last. Child nodes are InventoryCollection objects having
      # :parent_inventory_collections definition.
      #
      # @param nodes [Array<ManagerRefresh::InventoryCollection>] List of Inventory collection nodes
      # @return [Array<ManagerRefresh::InventoryCollection>] Sorted list of Inventory collection nodes
      def sort_nodes(nodes)
        # Separate to root nodes and child nodes, where child nodes are determined by having parent_inventory_collections
        root_nodes, child_nodes = nodes.partition { |node| node.parent_inventory_collections.blank? }
        # And order it that root nodes comes first, that way the disconnect of the child nodes should be always done as
        # a part of the root nodes, as intended.
        root_nodes + child_nodes
      end

      # Asserts all nodes are of class ::ManagerRefresh::InventoryCollection
      #
      # @param inventory_collections [Array<ManagerRefresh::InventoryCollection>] List of Inventory collection nodes
      def assert_inventory_collections(inventory_collections)
        inventory_collections.each do |inventory_collection|
          unless inventory_collection.kind_of?(::ManagerRefresh::InventoryCollection)
            raise "A ManagerRefresh::SaveInventory needs a InventoryCollection object, it got: #{inventory_collection.inspect}"
          end
        end
      end

      # Converts the graph into DAG
      #
      # @param nodes [Array<ManagerRefresh::InventoryCollection>] List of Inventory collection nodes
      # @param feedback_edge_set [Array<Array>] Is a set of edges that are causing a cycle in the graph
      # @return [ManagerRefresh::InventoryCollection::Graph] Graph object modified into DAG
      def convert_to_dag!(nodes, feedback_edge_set)
        new_nodes = []
        inventory_collection_transformations = {}
        nodes.each do |inventory_collection|
          feedback_dependencies = feedback_edge_set.select { |e| e.second == inventory_collection }.map(&:first)
          attrs                 = inventory_collection.dependency_attributes_for(feedback_dependencies)

          next if attrs.blank?

          new_inventory_collection = inventory_collection.clone

          # Add inventory_collection as a dependency of the new_inventory_collection, so we make sure it runs after
          # TODO(lsmola) add a nice dependency_attributes setter? It's used also in actualize_dependencies method
          new_inventory_collection.dependency_attributes[:__feedback_edge_set_parent] = Set.new([inventory_collection])
          new_nodes << new_inventory_collection

          inventory_collection.blacklist_attributes!(attrs)
          new_inventory_collection.whitelist_attributes!(attrs)

          # Store a simple hash for transforming inventory_collection to new_inventory_collection
          inventory_collection_transformations[inventory_collection] = new_inventory_collection
        end

        all_nodes = nodes + new_nodes

        # If we remove an attribute that was a dependency of another node, we need to move also the
        # dependency. So e.g. floating_ip depends on network_port's attribute vm, but we move that attribute to new
        # network_port inventory_collection. We will need to move also the dependency to point to the new
        # inventory_collection.
        #
        # So we have to go through all dependencies that loads a key, which is the moved attribute. We can get a list
        # of attributes that are using a key from transitive_dependency_attributes, from there we can get a list of
        # dependencies. And from the list of dependencies, we can check which ones were moved just by looking into
        # inventory_collection_transformations.
        all_nodes.each do |inventory_collection|
          inventory_collection.transitive_dependency_attributes.each do |transitive_dependency_attribute|
            transitive_dependencies = inventory_collection.dependency_attributes[transitive_dependency_attribute]
            next if transitive_dependencies.blank?

            transitive_dependencies.map! do |dependency|
              transformed_dependency = inventory_collection_transformations[dependency]
              transformed_dependency.blank? ? dependency : transformed_dependency
            end
          end
        end

        # Add the new InventoryCollections to the list of nodes our our graph
        construct_graph!(all_nodes)
      end

      # Build edges by introspecting the passed array of InventoryCollection objects
      #
      # @param inventory_collections [Array<ManagerRefresh::InventoryCollection>] List of Inventory collection nodes
      # @return [Array<Array>] Nested array representing edges
      def build_edges(inventory_collections)
        edges            = []
        transitive_edges = []
        fixed_edges = []
        inventory_collections.each do |inventory_collection|
          inventory_collection.dependencies.each do |dependency|
            fixed_edges << [dependency, inventory_collection] if inventory_collection.fixed_dependencies.include?(dependency)
            if inventory_collection.dependency_attributes_for([dependency]).any? { |x| inventory_collection.transitive_dependency_attributes.include?(x) }
              # The condition checks if the dependency is a transitive dependency, in other words a InventoryObjectLazy with :key
              # pointing to another object.
              transitive_edges << [dependency, inventory_collection]
            else
              edges << [dependency, inventory_collection]
            end
          end
        end
        # We put transitive edges to the end. Transitive edge is e.g.: given graph (X,Y,Z), we have a lazy link, from X
        # to Y, making edge (Y, X), using a :key pointing to Z. Which means that also edge from Y to Z (Z, Y) exists.
        # If the edge (Z, Y) is placed before (Y, X), we process it first. Then the edge (Y, X), causing hidden
        # transitive relation X to Z (it's hidden because edge (Z, X) is not present), is processed as last and we do a
        # more effective cycle removal if needed.
        return edges + transitive_edges, fixed_edges
      end
    end
  end
end
