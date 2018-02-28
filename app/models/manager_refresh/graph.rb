module ManagerRefresh
  class Graph
    attr_reader :nodes, :edges, :fixed_edges

    # @param nodes [Array<ManagerRefresh::InventoryCollection>] List of Inventory collection nodes
    def initialize(nodes)
      @nodes       = nodes
      @edges       = []
      @fixed_edges = []

      construct_graph!(@nodes)
    end

    # Returns graph in GraphViz format, as a string. So it can be displayed.
    #
    # @param layers [Array<Array>] Array of arrays(layers) of InventoryCollection objects
    # @return [String] Graph in GraphViz format
    def to_graphviz(layers: nil)
      node_names = friendly_unique_node_names
      s = []

      s << "digraph {"
      (layers || [nodes]).each_with_index do |layer_nodes, i|
        s << "  subgraph cluster_#{i} {  label = \"Layer #{i}\";" unless layers.nil?

        layer_nodes.each do |n|
          s << "    #{node_names[n]}; \t// #{n.inspect}"
        end

        s << "  }" unless layers.nil?
      end

      s << "  // edges:"
      edges.each do |from, to|
        s << "  #{node_names[from]} -> #{node_names[to]};"
      end
      s << "}"
      s.join("\n") + "\n"
    end

    protected

    attr_writer :nodes, :edges, :fixed_edges

    # Given array of InventoryCollection objects as nodes, we construct a graph with nodes and edges
    #
    # @param nodes [Array<ManagerRefresh::InventoryCollection>] List of Inventory collection nodes
    # @return [ManagerRefresh::Graph] Constructed graph
    def construct_graph!(nodes)
      self.nodes = nodes
      self.edges, self.fixed_edges = build_edges(nodes)
      self
    end

    # Checks that there are no cycles in the graph
    #
    # @param fixed_edges [Array<Array>] List of edges, where edge is defined as [InventoryCollection, InventoryCollection],
    #        fixed edges are those that can't be moved
    def assert_graph!(fixed_edges)
      fixed_edges.each do |edge|
        detect_cycle(edge, fixed_edges - [edge], :exception)
      end
    end

    # Builds a feedback edge set, which is a set of edges creating a cycle
    #
    # @param edges [Array<Array>] List of edges, where edge is defined as [InventoryCollection, InventoryCollection],
    #        these are all edges except fixed_edges
    # @param fixed_edges [Array<Array>] List of edges, where edge is defined as [InventoryCollection, InventoryCollection],
    #        fixed edges are those that can't be moved
    def build_feedback_edge_set(edges, fixed_edges)
      edges             = edges.dup
      acyclic_edges     = fixed_edges.dup
      feedback_edge_set = []

      while edges.present?
        edge = edges.shift
        if detect_cycle(edge, acyclic_edges)
          feedback_edge_set << edge
        else
          acyclic_edges << edge
        end
      end

      feedback_edge_set
    end

    # Detects a cycle. Based on escalation returns true or raises exception if there is a cycle
    #
    # @param edge [Array(ManagerRefresh::InventoryCollection, ManagerRefresh::InventoryCollection)] Edge we are
    #        inspecting for cycle
    # @param acyclic_edges [Array<Array>] Starting with fixed edges that can't have cycle, these are edges without cycle
    # @param escalation [Symbol] If :exception, this method throws exception when it finds a cycle
    # @return [Boolean, Exception] Based on escalation returns true or raises exception if there is a cycle
    def detect_cycle(edge, acyclic_edges, escalation = nil)
      # Test if adding edge creates a cycle, ew will traverse the graph from edge Node, through all it's
      # dependencies
      starting_node = edge.second
      edges         = [edge] + acyclic_edges
      traverse_dependecies([], starting_node, starting_node, edges, node_edges(edges, starting_node), escalation)
    end

    # Recursive method for traversing dependencies and finding a cycle
    #
    # @param traversed_nodes [Array<ManagerRefresh::InventoryCollection> Already traversed nodes
    # @param starting_node [ManagerRefresh::InventoryCollection] Node we've started the traversal on
    # @param current_node [ManagerRefresh::InventoryCollection] Node we are currently on
    # @param edges [Array<Array>] All graph edges
    # @param dependencies [Array<ManagerRefresh::InventoryCollection> Dependencies of the current node
    # @param escalation [Symbol] If :exception, this method throws exception when it finds a cycle
    # @return [Boolean, Exception] Based on escalation returns true or raises exception if there is a cycle
    def traverse_dependecies(traversed_nodes, starting_node, current_node, edges, dependencies, escalation)
      dependencies.each do |node_edge|
        node = node_edge.first
        traversed_nodes << node
        if traversed_nodes.include?(starting_node)
          if escalation == :exception
            raise "Cycle from #{current_node} to #{node}, starting from #{starting_node} passing #{traversed_nodes}"
          else
            return true
          end
        end
        return true if traverse_dependecies(traversed_nodes, starting_node, node, edges, node_edges(edges, node), escalation)
      end

      false
    end

    # Returns dependencies of the node, i.e. nodes that are connected by edge
    #
    # @param edges [Array<Array>] All graph edges
    # @param node [ManagerRefresh::InventoryCollection] Node we are inspecting
    # @return [Array<ManagerRefresh::InventoryCollection>] Nodes that are connected to the inspected node
    def node_edges(edges, node)
      edges.select { |e| e.second == node }
    end

    # Returns Hash of {node => name}, appending numbers if needed to make unique, quoted if needed. Used for the
    # GraphViz format
    #
    # @return [Hash] Hash of {node => name}
    def friendly_unique_node_names
      node_names = {}
      # Try to use shorter .name method that InventoryCollection has.
      nodes.group_by { |n| n.respond_to?(:name) ? n.name.to_s : n.to_s }.each do |base_name, ns|
        ns.each_with_index do |n, i|
          name = ns.size == 1 ? base_name : "#{base_name}_#{i}"
          name = '"' + name.gsub(/["\\]/) { |c| "\\" + c } + '"' unless name =~ /^[A-Za-z0-9_]+$/
          node_names[n] = name
        end
      end
      node_names
    end
  end
end
