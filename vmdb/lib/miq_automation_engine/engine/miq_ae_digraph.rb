module MiqAeEngine
  class MiqAeDigraph
    SEP = "-"

    def initialize
      @v    = Hash.new
      @from = Hash.new
      @lastid = -1
    end

    def nodes
      @v.values
    end

    def roots
      @v.keys.collect { |id| @v[id] if parents(id).blank? }.compact
    end

    def vertex(data)
      id = new_id
      @v[id] = data
      return id
    end

    def find_by_data(data)
      @v.key(data)
    end

    def dump
      puts "Vertex:"
      @v.each {|k, v| puts "\tkey=#{k}, value=#{v.inspect}"}
    end

    def delete(id)
      @v.delete(id)
      @from.each_key { |key|
        from, typ = key.split(SEP)
        from == id ? @from.delete(key) : @from[key].delete(id)
      }
    end

    def [](id)
      @v[id]
    end

    def parents(id)
      find_by_edge(id, "parent")
    end

    def children(id)
      find_by_edge(id, "child")
    end

    def find_by_edge(id, name)
      idx = [id, name].join(SEP)
      @from[idx]
    end

    def link_parent_child(parent, child)
      link(parent, "child", child)
      link(child, "parent", parent)
    end

    private

    def link(from, typ, to)
      key = [from, typ].join(SEP)
      @from[key] ||= []
      @from[key].push(to)
    end

    def new_id
      @lastid += 1
    end
  end

end
