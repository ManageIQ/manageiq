module MiqAeEngine
  class MiqAeDigraph
    class Node < Struct.new(:data, :parents, :children)
      def initialize(data)
        super(data, [], [])
      end
    end

    def initialize
      @nodes        = []
      @data_to_node = {}
    end

    def nodes
      @nodes.map(&:data)
    end

    def roots
      @nodes.select { |n| n.parents.empty? }.collect(&:data)
    end

    def vertex(data)
      node = Node.new(data)
      @nodes << node
      @data_to_node[data] = node
      node
    end

    def find_by_data(data)
      @data_to_node[data]
    end

    def dump
      puts "Vertex:"
      @nodes.each { |node| puts "\tkey=#{node.object_id}, value=#{node.data.inspect}" }
    end

    def delete(id)
      @data_to_node.delete(id.data)
      @nodes.delete(id)
      @nodes.each do |node|
        node.parents.delete id
        node.children.delete id
      end
    end

    def [](id)
      id.data
    end

    def parents(id)
      id.parents
    end

    def children(id)
      id.children
    end

    def link_parent_child(parent, child)
      parent.children << child
      child.parents << parent
    end
  end

end
