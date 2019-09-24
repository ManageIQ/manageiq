# When using STI with class hierarchies that are more than two levels
# deep, ActiveRecord relies on +descendants+ to retrieve all the
# expected records when querying from an "in-between" class. But the
# +descendants+ supplied by ActiveSupport can only know about classes
# that have been loaded.
#
# To address this, we must pre-parse all the class definitions in the
# application, noting inheritances. Then we wrap the built-in
# +descendants+ method, to explicitly load all previously-identified
# child classes, before ActiveSupport does its thing.
#
# While we don't do anything specifically for it, +subclasses+ will also
# work correctly, because it's implemented in terms of +descendants+.
#
#
# Example:
#   Given a class hierarchy of:
#
#     class Aaa < ActiveRecord::Base; end
#     class Bbb < Aaa; end
#     class Ccc < Bbb; end
#
#   Without this change, the following queries will be generated:
#
#     Aaa.count
#     # SELECT COUNT(*) FROM "aaas"
#     Bbb.count
#     # SELECT COUNT(*) FROM "aaas" WHERE "aaas"."type" IN ('Bbb')
#     Ccc.count
#     # SELECT COUNT(*) FROM "aaas" WHERE "aaas"."type" IN ('Ccc')
#
#   The `Bbb` query is incorrect since the application doesn't know
#   `Ccc` exists at the time. (Running `Bbb.count` again after `Ccc` is
#   loaded will give the correct result.)
#
#   With DescendantLoader, the correct queries will be generated:
#
#     Aaa.count
#     # SELECT COUNT(*) FROM "aaas"
#     Bbb.count
#     # SELECT COUNT(*) FROM "aaas" WHERE "aaas"."type" IN ('Bbb', 'Ccc')
#     Ccc.count
#     # SELECT COUNT(*) FROM "aaas" WHERE "aaas"."type" IN ('Ccc')
#
#   When Active Record calls `Bbb.descendants` to construct the `type`
#   condition, `Ccc` is automatically loaded.
#
class DescendantLoader
  CACHE_VERSION = 2

  def self.instance
    @instance ||= new
  end

  # Debug/tracing method only
  def self.status(io = $stdout)
    require 'miq-process'
    io.puts(MiqProcess.processInfo[:memory_usage] / 1024)

    l = ObjectSpace.each_object(Class).select { |c| c < ActiveRecord::Base }
    io.puts l.map(&:name).sort.join("  ")
    io.puts l.size
    io.puts
  end

  # Extract class definitions (namely: a list of which scopes it might
  # be defined in [depending on runtime details], the name of the class,
  # and the name of its superclass), given a path to a ruby script file.
  module Parser
    def classes_in(filename)
      require 'ripper_ruby_parser'

      content = File.read(filename)
      begin
        parsed = RipperRubyParser::Parser.new.parse(content, filename)
      rescue => e
        $stderr.puts "\nError parsing classes in #{filename}:\n#{e.class.name}: #{e}\n\n"
        raise
      end

      classes = collect_classes(parsed)

      classes.map do |(scopes, (_, name, sklass))|
        next unless sklass

        scope_names = scopes.map { |s| flatten_name(s) }
        search_combos = name_combinations(scope_names)

        # We're assuming this is the original class definition, so it
        # will definitely be defined inside the innermost containining
        # scope. We're just not sure how that scope plays out relative
        # to its parents.
        if (container_name = scope_names.pop)
          define_combos = scoped_name(container_name, name_combinations(scope_names))
        else
          define_combos = search_combos.dup
        end

        [search_combos, define_combos, flatten_name(name), flatten_name(sklass)]
      end.compact
    end

    def collect_classes(node, parents = [])
      type, *rest = node
      case type
      when :class
        name, superklass, *body = rest
        [[parents, [type, name, superklass]]] +
          body.flat_map { |n| collect_classes(n, parents + [name]) }
      when :module
        name, *body = rest
        body.flat_map { |n| collect_classes(n, parents + [name]) }
      when :block
        rest.flat_map { |n| collect_classes(n, parents) }
      when :cdecl
        name, superklass = rest
        if [:const, :colon2, :colon3].include?(superklass.first)
          [[parents, [type, name, superklass]]]
        else
          []
        end
      else
        []
      end
    end

    def flatten_name(node)
      return node.to_s if node.kind_of?(Symbol)

      type, *rest = node
      case type
      when :const
        rest.first.to_s
      when :colon2
        left, right = rest
        left = flatten_name(left)
        "#{left}::#{right}" if left
      when :colon3
        "::#{rest.first}"
      else
        raise "Unknown name node: #{type}"
      end
    end

    def name_combinations(names)
      combos = [[]]
      names.size.times do |n|
        combos += names.combination(n + 1).to_a
      end
      combos.each do |combo|
        if (i = combo.rindex { |s| s =~ /^::/ })
          combo.slice!(0, i)
          combo[0] = combo[0].sub(/^::/, '')
        end
      end
      combos.map { |c| c.join('::') }.uniq.reverse
    end
  end

  # RubyParser is slow, so wrap it in a simple mtime-based cache.
  module Cache
    def cache_path
      Rails.root.join('tmp/cache/sti_loader.yml')
    end

    def load_cache
      return unless cache_path.exist?
      data = YAML.load_file(cache_path)
      return unless data && data.kind_of?(Hash) && data['@version'].to_i == CACHE_VERSION
      data
    rescue
      nil
    end

    def cache
      @cache ||= load_cache || {'@version' => CACHE_VERSION}
    end

    def save_cache!
      return unless @cache_dirty
      cache_path.parent.mkpath
      cache_path.open('w') do |f|
        YAML.dump(cache, f)
      end
    end

    def classes_in(filename)
      t = File.mtime(filename)

      if (entry = cache[filename])
        return entry[:parsed] if entry[:mtime] == t
      end

      super.tap do |data|
        @cache_dirty = true
        cache[filename] = {:mtime => t, :parsed => data}
      end
    end
  end

  module Mapper
    def descendants_paths
      @descendants_paths ||= [Rails.root.join("app/models")]
    end

    def class_inheritance_relationships
      @class_inheritance_relationships ||= begin
        children = Hash.new { |h, k| h[k] = [] }
        Dir.glob(descendants_paths.map{|path| Pathname.new(path).join('**/*.rb')}) do |file|
          classes_in(file).each do |search_scopes, define_scopes, name, sklass|
            possible_names = scoped_name(name, define_scopes)
            possible_superklasses = scoped_name(sklass, search_scopes)

            possible_superklasses.each do |possible_superklass|
              children[possible_superklass].concat(possible_names)
            end
          end
        end
        children
      end
    end

    def clear_class_inheritance_relationships
      @class_inheritance_relationships = nil
    end
  end

  include Parser
  include Cache
  include Mapper

  def load_subclasses(parent)
    names_to_load = class_inheritance_relationships[parent.to_s].dup
    while (name = names_to_load.shift)
      if (_klass = name.safe_constantize) # this triggers the load
        names_to_load.concat(class_inheritance_relationships[name])
      end
    end
  end

  def scoped_name(name, scopes)
    if name =~ /^::(.*)/
      name = [$1]
    else
      scopes.map do |scope|
        scope.empty? ? name : "#{scope}::#{name}"
      end
    end
  end

  module ArDescendantsWithLoader
    def descendants
      unless defined? @loaded_descendants
        @loaded_descendants = true
        DescendantLoader.instance.load_subclasses(self)
      end

      super
    end
  end

  module AsDependenciesClearWithLoader
    def clear
      DescendantLoader.instance.clear_class_inheritance_relationships
      super
    end
  end
end

# Patch Class to support non-AR models in the models directory
Class.prepend(DescendantLoader::ArDescendantsWithLoader)
# Patch ActiveRecord specifically to get ahead of ActiveSupport::DescendantsTracker
#   The patching of Class does not put it in the right place in the ancestors chain
ActiveRecord::Base.singleton_class.prepend(DescendantLoader::ArDescendantsWithLoader)

at_exit do
  DescendantLoader.instance.save_cache!
end
