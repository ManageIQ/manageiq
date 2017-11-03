module ManagerRefresh
  class Graph
    attr_reader :nodes, :edges, :fixed_edges

    def initialize(nodes)
      @nodes       = nodes
      @edges       = []
      @fixed_edges = []

      construct_graph!(@nodes)
    end

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

    def construct_graph!(nodes)
      self.nodes = nodes
      self.edges, self.fixed_edges = build_edges(nodes)
      assert_edges_in_nodes!
      assert_fixed_edges_in_edges!
      self
    end

    def assert_edges_in_nodes!
      edge_endpoints = edges.collect_concat { |e| e }
      extra = edge_endpoints - nodes
      raise "Graph has edge endpoints that are not among its nodes: #{extra}" unless extra.empty?
    end

    def assert_fixed_edges_in_edges!
      extra = fixed_edges - edges
      raise "Graph has fixed_edges that are not in edges: #{extra}" unless extra.empty?
    end

    def assert_graph!(fixed_edges)
      fixed_edges.each do |edge|
        detect_cycle(edge, fixed_edges - [edge], :exception)
      end
    end

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

    def detect_cycle(edge, acyclic_edges, escalation = nil)
      # Test if adding edge creates a cycle, ew will traverse the graph from edge Node, through all it's
      # dependencies
      starting_node = edge.second
      edges         = [edge] + acyclic_edges
      traverse_dependecies([], starting_node, starting_node, edges, node_edges(edges, starting_node), escalation)
    end

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

    def node_edges(edges, node)
      edges.select { |e| e.second == node }
    end

    # Hash of {node => name}, appending numbers if needed to make unique, quoted if needed.
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
