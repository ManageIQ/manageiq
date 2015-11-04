class VirtualColumn < ActiveRecord::ConnectionAdapters::Column
  attr_reader :options

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

  TYPE_MAP = {
    :boolean     => ActiveRecord::Type::Boolean.new,
    :datetime    => ActiveRecord::Type::Time.new,
    :float       => ActiveRecord::Type::Float.new,
    :integer     => ActiveRecord::Type::Integer.new, # TODO: does a virtual_column :integer care if it's a Integer or BigInteger
    :numeric_set => Type::NumericSet.new,
    :string      => ActiveRecord::Type::String.new,
    :string_set  => Type::StringSet.new,
    :symbol      => Type::Symbol.new,                # TODO: is this correct?
    :time        => ActiveRecord::Type::Time.new,
  }

  def initialize(name, options)
    @options = options

    type = options[:type]

    if type.nil? && options.key?(:typ)
      unless Rails.env.production?
        msg = "[DEPRECATION] :typ option is deprecated.  Please use :type instead.  At #{caller[1]}"
        $log.warn msg
        warn msg
      end

      type = options[:typ]
      options[:type] = type
    end

    type = TYPE_MAP.fetch(type) unless type.kind_of?(ActiveRecord::Type::Value)

    raise ArgumentError, "type must be specified" if type.nil?

    super(name.to_s, options[:default], type)
  end

  def simplified_type(field_type)
    case field_type
    when /_set/
      field_type.to_sym
    else
      super || field_type.to_sym
    end
  end

  def klass
    super || type.to_s.camelize.constantize rescue nil
  end

  def typ
    unless Rails.env.production?
      msg = "[DEPRECATION] typ is deprecated.  Please use type instead.  At #{caller[1]}"
      $log.warn msg
      warn msg
    end

    type
  end

  alias_method :to_s, :inspect # Changes to_s to include all of the instance variables

  def uses
    options[:uses]
  end

  def uses=(val)
    options[:uses] = val
  end

  #
  # Deprecated backwards compatibility methods
  #

  def [](key)
    unless Rails.env.production?
      msg = "[DEPRECATION] [] access is deprecated.  Please use method call directly instead.  At #{caller[1]}"
      $log.warn msg
      warn msg
    end

    send(key)
  end

  def []=(key, val)
    unless Rails.env.production?
      msg = "[DEPRECATION] []= access is deprecated.  Please use method call directly instead.  At #{caller[1]}"
      $log.warn msg
      warn msg
    end

    send("#{key}=", val)
  end
end

class VirtualReflection < SimpleDelegator
  attr_accessor :uses

  def initialize(reflection, uses)
    super(reflection)
    @uses = uses
  end
end

module VirtualFields
  module NonARModels
    def dangerous_attribute_method?(_); false; end

    def generated_association_methods; self; end

    def add_autosave_association_callbacks(*_args); self; end
  end

  def self.extended(other)
    unless other.respond_to?(:dangerous_attribute_method?)
      other.extend NonARModels
    end
    other.class_eval { @virtual_fields_base = true }
  end

  def virtual_fields_base?
    @virtual_fields_base
  end

  #
  # Virtual Columns
  #

  def virtual_column(name, options = {})
    add_virtual_column(name, options)
  end

  def virtual_column?(name)
    virtual_columns_hash.key?(name.to_s)
  end

  #
  # Virtual Reflections
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
  # Accessors for fields, with inheritance
  #

  %w(columns_hash columns column_names column_names_symbols reflections).each do |m|
    define_method("virtual_#{m}") do
      inherited = send("inherited_virtual_#{m}")
      op = inherited.kind_of?(Hash) ? :merge : :"|"
      inherited.send(op, send("_virtual_#{m}"))
    end
  end

  %w(columns_hash columns column_names column_names_symbols).each do |m|
    define_method("#{m}_with_virtual") do
      inherited = send("inherited_#{m}_with_virtual")
      op = inherited.kind_of?(Hash) ? :merge : :"|"
      inherited.send(op, send("_virtual_#{m}"))
    end
  end

  def reflections_with_virtual
    reflections.symbolize_keys.merge(virtual_reflections)
  end

  def reflection_with_virtual(association)
    virtual_reflection(association) || reflect_on_association(association)
  end

  #
  # Common methods for Virtual Fields
  #

  def virtual_field?(name)
    virtual_column?(name) || virtual_reflection?(name)
  end

  def virtual_field(name)
    virtual_columns_hash[name.to_s] || virtual_reflections[name.to_sym]
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

  private

  def add_virtual_column(name, options)
    reset_virtual_column_information
    options[:type] = VirtualColumn::TYPE_MAP.fetch(options[:type]) do
      raise ArgumentError, "unknown type #{options[:type]}"
    end
    _virtual_columns_hash[name.to_s] = VirtualColumn.new(name, options)
  end

  def reset_virtual_column_information
    @virtual_columns = @virtual_column_names = @virtual_column_names_symbols = nil
  end

  def add_virtual_reflection(reflection, name, uses, _options)
    raise ArgumentError, "macro must be specified" unless reflection
    reset_virtual_reflection_information
    _virtual_reflections[name.to_sym] = VirtualReflection.new(reflection, uses)
  end

  def reset_virtual_reflection_information
  end

  #
  # Accessors for non-inherited fields
  #

  def _virtual_columns_hash
    @virtual_columns_hash ||= {}
  end

  def _virtual_columns
    @virtual_columns ||= _virtual_columns_hash.values
  end

  def _virtual_column_names
    @virtual_column_names ||= _virtual_columns_hash.keys
  end

  def _virtual_column_names_symbols
    @virtual_column_names_symbols ||= _virtual_column_names.collect(&:to_sym)
  end

  def _virtual_reflections
    @virtual_reflections ||= {}
  end

  #
  # Accessors for inherited fields
  #

  %w(columns_hash reflections).each do |m|
    define_method("inherited_virtual_#{m}") do
      superclass.virtual_fields_base? ? {} : superclass.send("virtual_#{m}")
    end
  end

  %w(columns column_names column_names_symbols).each do |m|
    define_method("inherited_virtual_#{m}") do
      superclass.virtual_fields_base? ? [] : superclass.send("virtual_#{m}")
    end
  end

  %w(columns column_names column_names_symbols columns_hash reflections).each do |m|
    define_method("inherited_#{m}_with_virtual") do
      superclass.virtual_fields_base? ? send(m) : superclass.send("#{m}_with_virtual")
    end
  end
end

#
# Class extensions
#

module ActiveRecord
  class Base
    extend VirtualFields
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
            field = records_model.virtual_field(parent)
            Array.wrap(field.uses).each { |f| preload(records, f) }

            raise "child must be blank if parent is a virtual column" if field.kind_of?(VirtualColumn) && !child.blank?
            next unless field.kind_of?(VirtualReflection)

            parents = records.map { |record| record.send(field.name) }.flatten.compact
            MiqPreloader.preload(parents, child) unless parents.empty?
          end
        when String, Symbol
          field = records_model.virtual_field(association)
          return Array.wrap(field.uses).each { |f| preload(records, f) } if field
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
    def calculate_with_virtual(operation, column_name, options = {})
      without_virtual_includes.send(:calculate_without_virtual, operation, column_name, options)
    end
    alias_method_chain :calculate, :virtual
  end
end
