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

module VirtualAttributes
  extend ActiveSupport::Concern
  include VirtualIncludes

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

  ActiveRecord::Type.register(:datetime, ActiveRecord::Type::DateTime) # Correct spelling is ":date_time"
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
          type = ActiveRecord::Type.lookup(type, **options.except(:uses))
        end

        define_virtual_attribute(name, type, **options.slice(:uses))
      end
    end

    def define_virtual_attribute(name, cast_type, uses: nil)
      attribute_types[name] = cast_type
      define_virtual_include name, uses
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
      def preloaders_on_with_virtual(association, records, preload_scope = nil)
        records = records.compact
        records_model = records.first.class
        return preloaders_on_without_virtual(association, records, preload_scope) if records.empty?

        case association
        when Hash
          virtual_association, association = association.partition do |parent, _child|
            raise "parent must be an association name" unless parent.kind_of?(String) || parent.kind_of?(Symbol)
            records_model.virtual_field?(parent)
          end
          association = Hash[association]

          virtual_association.each do |parent, child|
            Array.wrap(records_model.virtual_includes(parent)).each { |f| preload(records, f) }

            if records_model.virtual_attribute?(parent)
              raise "child must be blank if parent is a virtual attribute" if !child.blank?
              next
            end

            parents = records.map { |record| record.send(parent) }.flatten.compact
            MiqPreloader.preload(parents, child) unless parents.empty?
          end
        when String, Symbol
          return Array.wrap(records_model.virtual_includes(association)).each { |f| preload(records, f) }
        end

        preloaders_on_without_virtual(association, records, preload_scope)
      end
      alias_method_chain :preloaders_on, :virtual
    end
  end

  module FinderMethods
    def without_virtual_includes
      if includes_values
        spawn.without_virtual_includes!
      else
        self
      end
    end

    def without_virtual_includes!
      self.includes_values = klass.remove_virtual_fields(includes_values) if includes_values
      self
    end

    def find_with_associations_with_virtual
      recs = without_virtual_includes.send(:find_with_associations_without_virtual)

      if includes_values
        MiqPreloader.preload(recs, preload_values + includes_values)
      end

      recs
    end
    alias_method_chain :find_with_associations, :virtual
  end

  module Calculations
    def calculate_with_virtual(operation, attribute_name)
      without_virtual_includes.send(:calculate_without_virtual, operation, attribute_name)
    end
    alias_method_chain :calculate, :virtual
  end
end
