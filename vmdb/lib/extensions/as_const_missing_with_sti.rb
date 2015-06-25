require 'ruby_parser'

module AsConstMissingWithSti
  extend ActiveSupport::Concern

  included do
    alias_method_chain :const_missing, :sti
  end

  def self.collect_classes(node, parents = [])
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
    else
      []
    end
  end

  def self.classes_in(filename)
    content = File.read(filename)
    parsed = RubyParser.for_current_ruby.parse(content)

    collect_classes(parsed)
  end

  # Rails +const_missing+ only loads the requested constant and any of its
  # parents. However, when using STI and having class hierarchies that are
  # several levels deep, ActiveRecord requires that all descendants of a
  # model are loaded to generate the correct query. Additionally, the
  # methods +subclasses+ and +descendants+ require that all descendants of
  # a model are loaded in order to work as expected.
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
  #   The 'Bbb' query is incorrect since +const_missing+ does not load the
  #   child objects.
  #   With this change, the following queries will be generated:
  #
  #     Aaa.count
  #     # SELECT COUNT(*) FROM "aaas"
  #     Bbb.count
  #     # SELECT COUNT(*) FROM "aaas" WHERE "aaas"."type" IN ('Bbb', 'Ccc')
  #     Ccc.count
  #     # SELECT COUNT(*) FROM "aaas" WHERE "aaas"."type" IN ('Ccc')
  #
  def const_missing_with_sti(constant)
    AsConstMissingWithSti.nest do
      const_missing_without_sti(constant).tap do
        AsConstMissingWithSti.class_inheritance_relationships[constant.to_s].each do |c|
          AsConstMissingWithSti.enqueue_subclass(c)
        end
      end
    end
  end

  private

  ClassInheritanceRelationship = Struct.new(:subclass, :file_path)

  def self.flatten_name(node)
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

  def self.name_combinations(names)
    combos = [[]]
    names.size.times do |n|
      combos += names.combination(n + 1).to_a
    end
    combos.each do |combo|
      if (i = combo.rindex { |s| s =~ /^::/ })
        combo.slice! 0, i
        combo[0] = combo[0].sub(/^::/, '')
      end
    end
    combos.map { |c| c.join('::') }.uniq.reverse
  end

  def self.class_inheritance_relationships
    @class_inheritance_relationships ||= begin
      relats = Hash.new { |h, k| h[k] = [] }
      Dir.glob(Rails.root.join("app/models/**/*.rb")) do |file|
        classes_in(file).each do |(scopes, (_, name, sklass))|
          next unless sklass

          scope_names = scopes.map { |s| flatten_name(s) }
          combos = name_combinations(scope_names)

          name = flatten_name(name)
          sklass &&= flatten_name(sklass)

          sklasses = combos.map do |c|
            c.empty? ? sklass : "#{c}::#{sklass}"
          end
          names = combos.map do |c|
            c.empty? ? name : "#{c}::#{name}"
          end

          sklasses.each do |fqsklass|
            names.each do |fqname|
              relats[fqsklass].push(ClassInheritanceRelationship.new(fqname, File.expand_path(file)))
            end
          end
        end
      end
      relats
    end
  end

  def self.clear_class_inheritance_relationships
    @class_inheritance_relationships = nil
  end

  @queue = []
  def self.enqueue_subclass(relat)
    @queue << relat
  end

  @depth = 0
  def self.nest
    @depth += 1
    result = yield
    flush if @depth == 1
    result
  ensure
    @depth -= 1
  end

  def self.flush
    load_subclass(@queue.shift) until @queue.empty?
  end

  def self.load_subclass(relat)
    relat.subclass.safe_constantize unless ActiveSupport::Dependencies.loaded.include?(relat.file_path.sub(/\.rb\z/, ''))
  end
end

module AsDependenciesClearWithSti
  extend ActiveSupport::Concern

  included do
    alias_method_chain :clear, :sti
  end

  def clear_with_sti
    AsConstMissingWithSti.clear_class_inheritance_relationships
    clear_without_sti
  end
end

ActiveSupport::Dependencies::ModuleConstMissing.send(:include, AsConstMissingWithSti)
ActiveSupport::Dependencies.send(:include, AsDependenciesClearWithSti)

#ActiveSupport::Dependencies.log_activity = true
#ActiveSupport::Dependencies.logger = Logger.new($stdout)
