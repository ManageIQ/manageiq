# This is a modified version of the DerailedBenchmarks::RequireTree, originally
# authored by Richard Schneeman (@schneems):
#
#   https://github.com/schneems/derailed_benchmarks/blob/2a736e1/lib/derailed_benchmarks/require_tree.rb
#
# No current license exists.

# Tree structure used to store and sort require memory costs
# RequireTree.new('get_process_mem')

module MiqBenchmark
  class RequireTree
    attr_reader   :name
    attr_accessor :cost
    attr_accessor :parent

    def self.required_by
      @required_by ||= {}
    end

    def initialize(name)
      @name     = name
      @children = {}
    end

    def <<(tree)
      @children[tree.name.to_s] = tree
      tree.parent = self
      (self.class.required_by[tree.name.to_s] ||= []) << name
    end

    def [](name)
      @children[name.to_s]
    end

    # Returns array of child nodes
    def children
      @children.values
    end

    def cost
      @cost || 0
    end

    def short_name
      @short_name ||= name.gsub(/^#{Dir.home}.*\/bundler\/gems\//, '')
                          .gsub(/^([^\/]+)-[0-9a-f]+\//, '\1/')
                          .gsub(/^#{defined?(Rails) ? Rails.root : Dir.pwd}\//, '')
    end

    # Returns sorted array of child nodes from Largest to Smallest
    def sorted_children
      children.sort { |c1, c2| c2.cost <=> c1.cost }
    end

    def to_string
      str = "#{short_name}: #{cost.round(4)} MiB"
      if parent && self.class.required_by[name.to_s]
        names = self.class.required_by[name.to_s].uniq - [parent.name.to_s]
        if names.any?
          str << " (Also required by: #{names.first(2).join(", ")}"
          str << ", and #{names.count - 2} others" if names.count > 3
          str << ")"
        end
      end
      str
    end

    def flattened_full_hash_output(data = {})
      data[name] = cost
      sorted_children.each do |child|
        child.flattened_full_hash_output data
      end
      data
    end

    def full_hash_output(data = {})
      data["name"] = name
      data["cost"] = cost
      data["children"] = []
      sorted_children.each do |child|
        data["children"] << child.full_hash_output
      end
      data
    end

    # Recursively prints all child nodes
    def print_sorted_children(level = 0, out = STDOUT)
      return if cost < ENV['CUT_OFF'].to_f
      out.puts "  " * level + to_string
      level += 1
      sorted_children.each do |child|
        child.print_sorted_children(level, out)
      end
    end

    def print_summary(out = STDOUT)
      longest_name = sorted_children.map { |c| c.short_name.length }.max
      longest_cost = sorted_children.map { |c| c.cost.round(4).to_s.length }.max

      out.puts "\n\n\n"
      out.puts "SUMMARY ( TOTAL COST: #{cost.round(4)} MiB )"
      out.puts "-" * (longest_name + longest_cost + 7)

      sorted_children.each do |child|
        next if child.cost < ENV['CUT_OFF'].to_f
        out.puts [
          child.short_name.ljust(longest_name),
          "#{"%.4f" % child.cost} MiB".rjust(longest_cost + 4)
        ].join(' | ')
      end
    end
  end
end
