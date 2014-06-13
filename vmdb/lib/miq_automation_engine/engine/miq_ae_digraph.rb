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
      indices.collect { |id| @v[id] if parents(id).blank? }.compact
    end

    def indices
      @v.keys
    end

    def size
      @v.length
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

    def []=(id, data)
      @v[id] = data
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

    def unlink_parent_child(parent, child)
      unlink(child, "parent", parent)
      unlink(parent, "child", child)
    end

    def link(from, typ, to)
      key = [from, typ].join(SEP)
      @from[key] ||= []
      @from[key].push(to)
    end

    def unlink(from, typ, to)
      key = [from, typ].join(SEP)
      if @from[key]
        @from[key].delete(to)
        @from.delete(key) if @from[key].blank?
      end
    end

    def new_id
      @lastid += 1
    end
  end

end
