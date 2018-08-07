describe ManagerRefresh::Graph do
  let(:node1) { OpenStruct.new(:whatever => 'foo') }
  let(:node2) { OpenStruct.new(:name => 'bar', :x => 2) }
  let(:node3) { OpenStruct.new(:name => 'bar', :x => 3) }
  let(:node4) { OpenStruct.new(:name => 'quux') }
  let(:edges) { [[node1, node2], [node1, node3], [node2, node4]] }
  let(:fixed_edges) { [] }

  let(:test_graph_class) do
    Class.new(described_class) do
      def initialize(nodes, edges, fixed_edges)
        @nodes = nodes
        @edges = edges
        @fixed_edges = fixed_edges
      end
    end
  end

  let(:graph) { test_graph_class.new([node1, node2, node3, node4], edges, fixed_edges) }

  describe '#to_graphviz' do
    it 'prints the graph' do
      # sensitive to node and edge order, but test controls this
      expect(graph.to_graphviz).to eq(<<-'DOT'.strip_heredoc)
        digraph {
            "#<OpenStruct whatever=\"foo\">"; 	// #<OpenStruct whatever="foo">
            bar_0; 	// #<OpenStruct name="bar", x=2>
            bar_1; 	// #<OpenStruct name="bar", x=3>
            quux; 	// #<OpenStruct name="quux">
          // edges:
          "#<OpenStruct whatever=\"foo\">" -> bar_0;
          "#<OpenStruct whatever=\"foo\">" -> bar_1;
          bar_0 -> quux;
        }
      DOT
    end

    it 'prints the graph with layers' do
      layers = ManagerRefresh::Graph::TopologicalSort.new(graph).topological_sort
      expect(graph.to_graphviz(:layers => layers)).to eq(<<-'DOT'.strip_heredoc)
        digraph {
          subgraph cluster_0 {  label = "Layer 0";
            "#<OpenStruct whatever=\"foo\">"; 	// #<OpenStruct whatever="foo">
          }
          subgraph cluster_1 {  label = "Layer 1";
            bar_0; 	// #<OpenStruct name="bar", x=2>
            bar_1; 	// #<OpenStruct name="bar", x=3>
          }
          subgraph cluster_2 {  label = "Layer 2";
            quux; 	// #<OpenStruct name="quux">
          }
          // edges:
          "#<OpenStruct whatever=\"foo\">" -> bar_0;
          "#<OpenStruct whatever=\"foo\">" -> bar_1;
          bar_0 -> quux;
        }
      DOT
    end
  end
end
