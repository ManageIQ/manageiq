require 'query_relation'

class ActsAsArModel
  include Vmdb::Logging
  include ArVisibleAttribute

  def self.connection
    ActiveRecord::Base.connection
  end

  def connection
    self.class.connection
  end

  def self.table_name
    nil
  end

  def self.pluralize_table_names
    false
  end

  def self.base_class
    superclass == ActsAsArModel ? self : superclass.base_class
  end

  def self.includes_to_references(_inc)
    []
  end

  class << self; alias_method :base_model, :base_class; end

  #
  # Column methods
  #

  module FakeAttributeStore
    extend ActiveSupport::Concern

    # When ActiveRecord::Attributes gets [partially] extracted into
    # ActiveModel (hopefully in 5.1), this should become redundant. For
    # now, we'll just fake out the portion of the API we need.
    #
    # Based very heavily on matching methods in current ActiveRecord.

    module ClassMethods
      def load_schema
        load_schema! if @attribute_types.nil?
      end

      def load_schema!
        # no-op
      end

      def reload_schema_from_cache
        @attribute_types = nil
      end

      def attribute_types
        @attribute_types ||= Hash.new(ActiveModel::Type::Value.new)
      end

      def attribute_names
        load_schema
        attribute_types.keys
      end

      def has_attribute?(name)
        load_schema
        attribute_types.key?(name.to_s)
      end

      def type_for_attribute(attr_name)
        load_schema
        attribute_types[attr_name]
      end
    end
  end

  module AttributeBag
    def initialize
      @attributes = {}
    end

    def attributes=(values)
      values.each do |attr, value|
        send(:"#{attr}=", value)
      end
    end

    def attributes
      @attributes.dup
    end

    def [](attr)
      @attributes[attr.to_s]
    end
    alias_method :read_attribute, :[]

    def []=(attr, value)
      @attributes[attr.to_s] = value
    end
    alias_method :write_attribute, :[]=
  end

  def self.set_columns_hash(hash)
    hash[:id] ||= :integer

    hash.each do |attribute, type|
      virtual_attribute attribute, type

      define_method(attribute) do
        read_attribute(attribute)
      end

      define_method(:"#{attribute}=") do |val|
        write_attribute(attribute, val)
      end
    end
  end

  include FakeAttributeStore
  include ActiveRecord::VirtualAttributes::VirtualFields

  include AttributeBag
  extend QueryRelation::Queryable

  def self.instances_are_derived?
    true
  end

  def self.reflect_on_association(name)
    virtual_reflection(name)
  end

  def initialize(values = {})
    super()
    self.attributes = values
  end

  #
  # Reflection methods
  #

  def self.reflections
    @reflections ||= {}
  end

  #
  # Find routines
  #
  def self.find(mode_or_id, *args)
    if %i[all first last].include?(mode_or_id)
      Vmdb::Deprecation.warn("find(:#{mode_or_id}) is deprecated (use #{mode_or_id} instead)")
      search(mode_or_id, from_legacy_options(args.extract_options!))
    else
      lookup_by_id(mode_or_id, *args).tap do |record|
        raise ActiveRecord::RecordNotFound, "Couldn't find #{self} with id=#{mode_or_id}" if record.nil?
      end
    end
  end

  def self.search(mode, options)
    raise NotImplementedError, "must be defined in a subclass"
  end

  def self.from_legacy_options(options)
    {
      :where    => options[:conditions],
      :includes => options[:include],
      :limit    => options[:limit],
      :order    => options[:order],
      :offset   => options[:offset],
      :select   => options[:select],
      :group    => options[:group],
    }.delete_blanks
  end
  private_class_method :from_legacy_options

  def self.find_by_id(*id)
    options = id.extract_options!
    options[:where] = {:id => id.first}
    search(:first, options)
  end

  singleton_class.send(:alias_method, :lookup_by_id, :find_by_id)
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_by_id => :lookup_by_id)

  def self.find_all_by_id(*ids)
    options = ids.extract_options!
    options[:where] = {:id => ids.flatten}
    search(:all, options)
  end
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_all_by_id => "use where(:id => ids) instead")

  #
  # Methods pulled from ActiveRecord 2.3.8
  #

  # Returns the contents of the record as a nicely formatted string.
  def inspect
    attributes_as_nice_string = self.class.attribute_names.collect do |name|
      "#{name}: #{attribute_for_inspect(name)}"
    end.compact.join(", ")
    "#<#{self.class} #{attributes_as_nice_string}>"
  end

  private

  # Returns an <tt>#inspect</tt>-like string for the value of the
  # attribute +attr_name+. String attributes are elided after 50
  # characters, and Date and Time attributes are returned in the
  # <tt>:db</tt> format. Other attributes return the value of
  # <tt>#inspect</tt> without modification.
  #
  #   person = Person.create!(:name => "David Heinemeier Hansson " * 3)
  #
  #   person.attribute_for_inspect(:name)
  #   # => '"David Heinemeier Hansson David Heinemeier Hansson D..."'
  #
  #   person.attribute_for_inspect(:created_at)
  #   # => '"2009-01-12 04:48:57"'
  def attribute_for_inspect(attr_name)
    value = self[attr_name]

    if value.kind_of?(String) && value.length > 50
      "#{value[0..50]}...".inspect
    elsif value.kind_of?(Date) || value.kind_of?(Time)
      %("#{value.to_fs(:db)}")
    else
      value.inspect
    end
  end
end
