module AsConstMissingWithSti
  extend ActiveSupport::Concern

  included do
    alias_method_chain :const_missing, :sti
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
    const_missing_without_sti(constant).tap do
      AsConstMissingWithSti.class_inheritance_relationships[constant.to_s].each { |c| AsConstMissingWithSti.load_subclass(c) }
    end
  end

  private

  ClassInheritanceRelationship = Struct.new(:subclass, :file_path)

  def self.class_inheritance_relationships
    @class_inheritance_relationships ||= begin
      relats = Hash.new { |h, k| h[k] = [] }
      Dir.glob(Rails.root.join("app/models/*.rb")).each_with_object(relats) do |file, h|
        File.foreach(file) do |l|
          match = l.match(/^\s*class\s+(\w+)\s*<\s*(\w+)/)
          next unless match

          child, parent = match.values_at(1, 2)
          h[parent].push(ClassInheritanceRelationship.new(child, File.expand_path(file)))
        end
      end
    end
  end

  def self.clear_class_inheritance_relationships
    @class_inheritance_relationships = nil
  end

  def self.load_subclass(relat)
    Object.const_get(relat.subclass) unless ActiveSupport::Dependencies.loaded.include?(relat.file_path.sub(/\.rb\z/, ''))
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
