module ManagerRefresh
  class Graph
    attr_reader :nodes, :edges, :fixed_edges

    def initialize(nodes)
      @nodes       = nodes
      @edges       = []
      @fixed_edges = []

      construct_graph!(@nodes)
    end

    protected

    attr_writer :nodes, :edges, :fixed_edges

    def construct_graph!(nodes)
      self.nodes = nodes
      self.edges, self.fixed_edges = build_edges(nodes)
      self
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
        edge = edges.pop
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
  end
end
