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
    autoload :Prism, 'prism'

    def classes_in(filename)
      begin
        parsed = Prism::Translation::RubyParser.parse_file(filename)
      rescue => e
        warn "\nError parsing classes in #{filename}:\n#{e.class.name}: #{e}\n\n"
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

      data = File.open(cache_path, "r") do |f|
        f.flock(File::LOCK_SH)
        YAML.load(f.read)
      end

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

      # Don't write sti_loader.yml in production, this shouldn't change from what is in the RPM
      if Rails.env.production?
        warn "\nSTI cache is out of date in production, check that source files haven't been modified"
      else
        cache_path.parent.mkpath
        cache_path.open('w') do |f|
          f.flock(File::LOCK_EX)
          YAML.dump(cache, f)
        end
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
        Dir.glob(descendants_paths.map { |path| Pathname.new(path).join('**/*.rb') }) do |file|
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
    # Use caution if modifying the list of excluded caller_locations below.
    # These methods are called very early from rails during code load time,
    # before the models are even loaded, as documented below.
    # Ideally, a more resilient conditional can be used in the future.
    #
    # Called from __update_callbacks during model load time:
    #   "xxx/gems/activesupport-7.0.8.4/lib/active_support/callbacks.rb:706:in `__update_callbacks'",
    #   "xxx/gems/activesupport-7.0.8.4/lib/active_support/callbacks.rb:764:in `set_callback'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations.rb:172:in `validate'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations/with.rb:96:in `block in validates_with'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations/with.rb:85:in `each'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations/with.rb:85:in `validates_with'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations/format.rb:109:in `validates_format_of'",
    #   "xxx/gems/ancestry-4.1.0/lib/ancestry/has_ancestry.rb:30:in `has_ancestry'",
    #   "xxx/manageiq/app/models/vm_or_template.rb:15:in `<class:VmOrTemplate>'",
    #   "xxx/manageiq/app/models/vm_or_template.rb:6:in `<main>'",
    def descendants
      if Vmdb::Application.instance.initialized? && !defined?(@loaded_descendants) && %w[__update_callbacks].exclude?(caller_locations(1..1).first.base_label)
        @loaded_descendants = true
        DescendantLoader.instance.load_subclasses(self)
      end

      super
    end

    # Use caution if modifying the list of excluded caller_locations below.
    # These methods are called very early from rails during code load time,
    # before the models are even loaded, as documented below.
    # Ideally, a more resilient conditional can be used in the future.
    #
    # Called from reload_schema_from_cache from virtual column definitions from ar_region from many/all models:
    #   "xxx/gems/activerecord-7.0.8.4/lib/active_record/model_schema.rb:609:in `reload_schema_from_cache'",
    #   "xxx/gems/activerecord-7.0.8.4/lib/active_record/timestamp.rb:94:in `reload_schema_from_cache'",
    #   "xxx/bundler/gems/activerecord-virtual_attributes-2c077434608f/lib/active_record/virtual_attributes.rb:60:in `virtual_attribute'",
    #   "xxx/bundler/gems/activerecord-virtual_attributes-2c077434608f/lib/active_record/virtual_attributes.rb:55:in `virtual_column'",
    #   "xxx/manageiq/lib/extensions/ar_region.rb:14:in `block in inherited'",
    #   "xxx/manageiq/lib/extensions/ar_region.rb:13:in `class_eval'",
    #   "xxx/manageiq/lib/extensions/ar_region.rb:13:in `inherited'",
    #   "xxx/manageiq/app/models/vm_or_template.rb:6:in `<main>'",
    #
    # Called from subclasses call in descendant_loader after the above callstack:
    #   "xxx/gems/activesupport-7.0.8.4/lib/active_support/descendants_tracker.rb:83:in `subclasses'",
    #   "xxx/manageiq/lib/extensions/descendant_loader.rb:313:in `subclasses'",
    #   "xxx/gems/activerecord-7.0.8.4/lib/active_record/model_schema.rb:609:in `reload_schema_from_cache'",
    #   ...
    #
    # Called from descendants from descendant_loader via  __update_callbacks:
    #   "xxx/gems/activesupport-7.0.8.4/lib/active_support/descendants_tracker.rb:89:in `descendants'",
    #   "xxx/manageiq/lib/extensions/descendant_loader.rb:296:in `descendants'",
    #   "xxx/gems/activesupport-7.0.8.4/lib/active_support/callbacks.rb:706:in `__update_callbacks'",
    #   "xxx/gems/activesupport-7.0.8.4/lib/active_support/callbacks.rb:764:in `set_callback'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations.rb:172:in `validate'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations/with.rb:96:in `block in validates_with'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations/with.rb:85:in `each'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations/with.rb:85:in `validates_with'",
    #   "xxx/gems/activemodel-7.0.8.4/lib/active_model/validations/format.rb:109:in `validates_format_of'",
    #   "xxx/gems/ancestry-4.1.0/lib/ancestry/has_ancestry.rb:30:in `has_ancestry'",
    #   "xxx/manageiq/app/models/vm_or_template.rb:15:in `<class:VmOrTemplate>'",
    #   "xxx/manageiq/app/models/vm_or_template.rb:6:in `<main>'",
    #
    # Called from subclasses from above callstack:
    #   "xxx/gems/activesupport-7.0.8.4/lib/active_support/descendants_tracker.rb:83:in `subclasses'",
    #   "xxx/manageiq/lib/extensions/descendant_loader.rb:313:in `subclasses'",
    #   "xxx/gems/activesupport-7.0.8.4/lib/active_support/descendants_tracker.rb:89:in `descendants'",
    #   ...
    def subclasses
      if Vmdb::Application.instance.initialized? && !defined?(@loaded_descendants) && %w[descendants reload_schema_from_cache subclasses].exclude?(caller_locations(1..1).first.base_label)
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
