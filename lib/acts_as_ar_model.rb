class ActsAsArModel
  include Vmdb::Logging

  def self.connection
    ActiveRecord::Base.connection
  end

  def self.sortable?
    false
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
        send("#{attr}=", value)
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

      define_method("#{attribute}=") do |val|
        write_attribute(attribute, val)
      end
    end
  end

  include FakeAttributeStore
  include VirtualFields

  include AttributeBag

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

  def self.where(*args)
    return aar_scope.where(*args) if self.respond_to?(:aar_scope)
    raise NotImplementedError
  end

  def self.find(*args)
    return aar_scope.find(*args) if self.respond_to?(:aar_scope)
    raise NotImplementedError
  end

  def self.all(*args)
    if !self.respond_to?(:aar_scope)
      find(:all, *args)
    elsif args.empty? || args.size == 1 && args.first.respond_to?(:empty?) && args.first.empty?
      # avoid warnings
      aar_scope
    else
      aar_scope.all(*args)
    end
  end

  def self.first(*args)
    return aar_scope.first(*args) if self.respond_to?(:aar_scope)
    find(:first, *args)
  end

  def self.last(*args)
    return aar_scope.last(*args) if self.respond_to?(:aar_scope)
    find(:last, *args)
  end

  def self.count(*args)
    return aar_scope.count(*args) if self.respond_to?(:aar_scope)
    all(*args).size
  end

  def self.find_by_id(*id)
    return aar_scope.find_by_id(*id) if self.respond_to?(:aar_scope)
    options = id.extract_options!
    options.merge!(:conditions => {:id => id.first})
    first(options)
  end

  def self.find_all_by_id(*ids)
    return aar_scope.find_all_by_id(*args) if self.respond_to?(:aar_scope)
    options = ids.extract_options!
    options.merge!(:conditions => {:id => ids.flatten})
    all(options)
  end

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
      %("#{value.to_s(:db)}")
    else
      value.inspect
    end
  end
end
