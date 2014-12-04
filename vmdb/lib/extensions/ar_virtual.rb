class VirtualColumn < ActiveRecord::ConnectionAdapters::Column
  attr_reader :options

  def initialize(name, options)
    @options = options

    type = options[:type]

    if type.nil? && options.has_key?(:typ)
      unless Rails.env.production?
        msg = "[DEPRECATION] :typ option is deprecated.  Please use :type instead.  At #{caller[1]}"
        $log.warn msg
        warn msg
      end

      type = options[:typ]
      options[:type] = type
    end

    raise ArgumentError, "type must be specified" if type.nil?

    super(name.to_s, options[:default], type.to_s)
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

  alias to_s inspect # Changes to_s to include all of the instance variables

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

    self.send(key)
  end

  def []=(key, val)
    unless Rails.env.production?
      msg = "[DEPRECATION] []= access is deprecated.  Please use method call directly instead.  At #{caller[1]}"
      $log.warn msg
      warn msg
    end

    self.send("#{key}=", val)
  end
end

class VirtualReflection < ActiveRecord::Reflection::AssociationReflection
  def uses
    options[:uses]
  end

  def uses=(val)
    options[:uses] = val
  end

  alias to_s inspect # Changes to_s to include all of the instance variables
end

module VirtualFields
  def self.extended(other)
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

  def virtual_columns=(column_hash)
    column_hash.each do |name, options|
      add_virtual_column(name, options)
    end
  end

  def virtual_column?(name)
    virtual_columns_hash.has_key?(name.to_s)
  end

  #
  # Virtual Reflections
  #

  def virtual_has_one(name, options = {})
    add_virtual_reflection(:has_one, name, options)
  end

  def virtual_has_many(name, options = {})
    add_virtual_reflection(:has_many, name, options)
  end

  def virtual_belongs_to(name, options = {})
    add_virtual_reflection(:belongs_to, name, options)
  end

  def virtual_reflections=(reflection_hash)
    reflection_hash.each do |name, options|
      add_virtual_reflection(options.kind_of?(VirtualReflection) ? options.macro : options[:macro], name, options)
    end
  end

  def virtual_reflection?(name)
    virtual_reflections.has_key?(name.to_sym)
  end

  #
  # Accessors for fields, with inheritance
  #

  %w{columns_hash columns column_names column_names_symbols reflections}.each do |m|
    define_method("virtual_#{m}") do
      inherited = self.send("inherited_virtual_#{m}")
      op = inherited.kind_of?(Hash) ? :merge : :"+"
      inherited.send(op, self.send("_virtual_#{m}"))
    end
  end

  %w{columns_hash columns column_names column_names_symbols}.each do |m|
    define_method("#{m}_with_virtual") do
      inherited = self.send("inherited_#{m}_with_virtual")
      op = inherited.kind_of?(Hash) ? :merge : :"+"
      inherited.send(op, self.send("_virtual_#{m}"))
    end
  end

  def reflections_with_virtual
    reflections.merge(virtual_reflections)
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
        reflection = reflections[parent.to_sym]
        h[parent] = reflection.options[:polymorphic] ? nil : reflection.klass.remove_virtual_fields(child) if reflection
      end
    else
      associations
    end
  end

  private

  def add_virtual_column(name, options)
    reset_virtual_column_information
    _virtual_columns_hash[name.to_s] = VirtualColumn.new(name, options)
  end

  def reset_virtual_column_information
    @virtual_columns = @virtual_column_names = @virtual_column_names_symbols = nil
  end

  def add_virtual_reflection(macro, name, options)
    raise ArgumentError, "macro must be specified" if macro.nil?
    reset_virtual_reflection_information
    _virtual_reflections[name.to_sym] = VirtualReflection.new(macro.to_sym, name.to_sym, options, self)
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

  %w{columns_hash reflections}.each do |m|
    define_method("inherited_virtual_#{m}") do
      superclass.virtual_fields_base? ? {} : superclass.send("virtual_#{m}")
    end
  end

  %w{columns column_names column_names_symbols}.each do |m|
    define_method("inherited_virtual_#{m}") do
      superclass.virtual_fields_base? ? [] : superclass.send("virtual_#{m}")
    end
  end

  %w{columns column_names column_names_symbols columns_hash reflections}.each do |m|
    define_method("inherited_#{m}_with_virtual") do
      superclass.virtual_fields_base? ? self.send(m) : superclass.send("#{m}_with_virtual")
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
      def preload_with_virtual(association)
        records_model = records.first.class

        case association
        when Hash
          virtual_association, association = association.partition do |parent, child|
            raise "parent must be an association name" unless parent.is_a?(String) || parent.is_a?(Symbol)
            records_model.virtual_field?(parent)
          end
          association = Hash[association]

          virtual_association.each do |parent, child|
            field = records_model.virtual_field(parent)
            Array.wrap(field.uses).each { |f| preload(f) }

            raise "child must be blank if parent is a virtual column" if field.kind_of?(VirtualColumn) && !child.blank?
            next unless field.kind_of?(VirtualReflection)

            parents = records.map {|record| record.send(field.name)}.flatten.compact
            Preloader.new(parents, child).run unless parents.empty?
          end
        when String, Symbol
          field = records_model.virtual_field(association)
          return Array.wrap(field.uses).each { |f| preload(f) } if field
        end

        preload_without_virtual(association)
      end
      alias_method_chain :preload, :virtual
    end
  end

  module FinderMethods
    def find_with_associations_with_virtual
      original, @includes_values = @includes_values, klass.remove_virtual_fields(@includes_values) if @includes_values

      recs = find_with_associations_without_virtual

      if original
        @includes_values = original
        ActiveRecord::Associations::Preloader.new(recs, @preload_values + @includes_values).run
      end
      return recs
    end
    alias_method_chain :find_with_associations, :virtual
  end

  module Calculations
    def calculate_with_virtual(operation, column_name, options = {})
      original, @includes_values = @includes_values, klass.remove_virtual_fields(@includes_values) if @includes_values
      result = calculate_without_virtual(operation, column_name, options)
      @includes_values = original if original
      return result
    end
    alias_method_chain :calculate, :virtual
  end
end
