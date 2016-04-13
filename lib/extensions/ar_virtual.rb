module VirtualIncludes
  extend ActiveSupport::Concern

  included do
    class_attribute :_virtual_includes, :instance_accessor => false
    self._virtual_includes = {}
  end

  module ClassMethods
    def virtual_includes(name)
      load_schema
      _virtual_includes[name.to_s]
    end

    private

    def define_virtual_include(name, uses)
      self._virtual_includes = _virtual_includes.merge(name => uses)
    end
  end
end

module VirtualArel
  extend ActiveSupport::Concern

  included do
    class_attribute :_virtual_arel, :instance_accessor => false
    self._virtual_arel = {}
  end

  module ClassMethods
    # not thrilled with this
    def arel_attribute_alias?(column_name)
      _virtual_arel.key?(column_name.to_s)
    end

    def arel_attribute(column_name, arel_table = self.arel_table)
      load_schema
      if virtual_attribute?(column_name)
        col = _virtual_arel[column_name.to_s]
        col.call(arel_table) if col
      else
        super
      end
    end

    private

    def define_virtual_arel(name, arel)
      self._virtual_arel = _virtual_arel.merge(name => arel)
    end
  end
end

module VirtualAttributes
  extend ActiveSupport::Concern
  include VirtualIncludes
  include VirtualArel

  module Type
    # TODO: do we actually need symbol types?
    class Symbol < ActiveRecord::Type::String
      def type; :symbol; end
    end

    class StringSet < ActiveRecord::Type::Value
      def type; :string_set; end
    end

    class NumericSet < ActiveRecord::Type::Value
      def type; :numeric_set; end
    end
  end

  ActiveRecord::Type.register(:numeric_set, Type::NumericSet)
  ActiveRecord::Type.register(:string_set, Type::StringSet)
  ActiveRecord::Type.register(:symbol, Type::Symbol)

  included do
    class_attribute :virtual_attributes_to_define, :instance_accessor => false
    self.virtual_attributes_to_define = {}
  end

  module ClassMethods

    #
    # Definition
    #

    # Compatibility method: `virtual_attribute` is a more accurate name
    def virtual_column(name, type_or_options, **options)
      if type_or_options.kind_of?(Hash)
        options = options.merge(type_or_options)
        type = options.delete(:type)
      else
        type = type_or_options
      end

      virtual_attribute(name, type, **options)
    end

    def virtual_attribute(name, type, **options)
      name = name.to_s
      reload_schema_from_cache

      self.virtual_attributes_to_define =
        virtual_attributes_to_define.merge(name => [type, options])
    end

    #
    # Introspection
    #

    def virtual_attribute?(name)
      load_schema
      has_attribute?(name) && (
        !respond_to?(:column_for_attribute) ||
        column_for_attribute(name).kind_of?(ActiveRecord::ConnectionAdapters::NullColumn)
      )
    end

    def virtual_attribute_names
      if respond_to?(:column_names)
        attribute_names - column_names
      else
        attribute_names
      end
    end

    private

    def load_schema!
      super

      virtual_attributes_to_define.each do |name, (type, options)|
        if type.is_a?(Symbol)
          type = ActiveRecord::Type.lookup(type, **options.except(:uses, :arel))
        end

        define_virtual_attribute(name, type, **options.slice(:uses, :arel))
      end
    end

    def define_virtual_attribute(name, cast_type, uses: nil, arel: nil)
      attribute_types[name] = cast_type
      define_virtual_include name, uses if uses
      define_virtual_arel name, arel if arel
    end
  end
end

module VirtualReflections
  extend ActiveSupport::Concern
  include VirtualIncludes

  module ClassMethods

    #
    # Definition
    #

    def virtual_has_one(name, options = {})
      uses = options.delete :uses
      reflection = ActiveRecord::Associations::Builder::HasOne.build(self, name, nil, options)
      add_virtual_reflection(reflection, name, uses, options)
    end

    def virtual_has_many(name, options = {})
      define_method("#{name.to_s.singularize}_ids") do
        records = send(name)
        records.respond_to?(:ids) ? records.ids : records.collect(&:id)
      end
      uses = options.delete :uses
      reflection = ActiveRecord::Associations::Builder::HasMany.build(self, name, nil, options)
      add_virtual_reflection(reflection, name, uses, options)
    end

    def virtual_belongs_to(name, options = {})
      uses = options.delete :uses
      reflection = ActiveRecord::Associations::Builder::BelongsTo.build(self, name, nil, options)
      add_virtual_reflection(reflection, name, uses, options)
    end

    def virtual_reflection?(name)
      virtual_reflections.key?(name.to_sym)
    end

    def virtual_reflection(name)
      virtual_reflections[name.to_sym]
    end

    #
    # Introspection
    #

    def virtual_reflections
      (virtual_fields_base? ? {} : superclass.virtual_reflections).merge _virtual_reflections
    end

    def reflections_with_virtual
      reflections.symbolize_keys.merge(virtual_reflections)
    end

    def reflection_with_virtual(association)
      virtual_reflection(association) || reflect_on_association(association)
    end

    def follow_associations(association_names)
      association_names.inject(self) { |klass, name| klass.try!(:reflect_on_association, name).try!(:klass) }
    end

    def follow_associations_with_virtual(association_names)
      association_names.inject(self) { |klass, name| klass.try!(:reflection_with_virtual, name).try!(:klass) }
    end

    private

    def add_virtual_reflection(reflection, name, uses, _options)
      raise ArgumentError, "macro must be specified" unless reflection
      reset_virtual_reflection_information
      _virtual_reflections[name.to_sym] = reflection
      define_virtual_include(name.to_s, uses)
    end

    def reset_virtual_reflection_information
    end

    def _virtual_reflections
      @virtual_reflections ||= {}
    end
  end
end

module VirtualFields
  extend ActiveSupport::Concern
  include VirtualAttributes
  include VirtualReflections

  module NonARModels
    def dangerous_attribute_method?(_); false; end

    def generated_association_methods; self; end

    def add_autosave_association_callbacks(*_args); self; end

    def belongs_to_required_by_default; false; end
  end

  included do
    unless respond_to?(:dangerous_attribute_method?)
      extend NonARModels
    end
  end

  module ClassMethods
    def virtual_fields_base?
      !(superclass < VirtualFields)
    end

    def virtual_field?(name)
      virtual_attribute?(name) || virtual_reflection?(name)
    end

    def remove_virtual_fields(associations)
      case associations
      when String, Symbol
        virtual_field?(associations) ? nil : associations
      when Array
        associations.collect { |association| remove_virtual_fields(association) }.compact
      when Hash
        associations.each_with_object({}) do |(parent, child), h|
          next if virtual_field?(parent)
          reflection = reflect_on_association(parent.to_sym)
          h[parent] = reflection.options[:polymorphic] ? nil : reflection.klass.remove_virtual_fields(child) if reflection
        end
      else
        associations
      end
    end
  end
end

#
# Class extensions
#

module ActiveRecord
  class Base
    include VirtualFields
  end

  module Associations
    class Preloader
      prepend Module.new {
        def preloaders_for_one(association, records, scope)
          klass_map = records.compact.group_by(&:class)

          loaders = klass_map.keys.group_by { |klass| klass.virtual_includes(association) }.flat_map do |virtuals, klasses|
            subset = klasses.flat_map { |klass| klass_map[klass] }
            preload subset, virtuals
          end

          records_with_association = klass_map.select { |k, rs| k.reflect_on_association(association) }.flat_map { |k, rs| rs }
          if records_with_association.any?
            loaders.concat super(association, records_with_association, scope)
          end

          loaders
        end
      }
    end
  end

  class Relation
    def without_virtual_includes
      filtered_includes = includes_values && klass.remove_virtual_fields(includes_values)
      if filtered_includes != includes_values
        spawn.tap { |other| other.includes_values = filtered_includes }
      else
        self
      end
    end

    include Module.new {
      # From ActiveRecord::FinderMethods
      def find_with_associations
        real = without_virtual_includes
        return super if real.equal?(self)

        recs = real.find_with_associations
        MiqPreloader.preload(recs, preload_values + includes_values) if includes_values

        recs
      end

      # From ActiveRecord::Calculations
      def calculate(operation, attribute_name)
        real = without_virtual_includes
        return super if real.equal?(self)

        real.calculate(operation, attribute_name)
      end
    }
  end
end
