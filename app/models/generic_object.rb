class GenericObject < ApplicationRecord
  belongs_to :generic_object_definition

  validates :name, :presence => true

  has_many :custom_attributes, :as => :resource, :dependent => :destroy, :autosave => true
  private  :custom_attributes, :custom_attributes=

  delegate :property_attribute_defined?, :to => :generic_object_definition, :allow_nil => true

  def initialize(attributes = {})
    # generic_object_definition will be set first since hash iteration is based on the order of key insertion
    attributes = (attributes || {}).symbolize_keys
    attributes = attributes.slice(:generic_object_definition).merge(attributes.except(:generic_object_definition))
    super
  end

  def inspect
    attributes_as_string = self.class.column_names.collect do |name|
      "#{name}: #{attribute_for_inspect(name)}"
    end

    attributes_as_string += custom_attributes.collect do |ca|
      "#{ca.name}: #{ca_attribute_for_inspect(custom_attribute_getter(ca.name))}"
    end

    "#<#{self.class} #{attributes_as_string.join(", ")}>"
  end

  def property_attributes
    custom_attributes.each_with_object({}) { |ca, h| h[ca.name] = custom_attribute_getter(ca.name) }
  end

  def property_attributes=(options)
    raise "generic_object_definition is nil" unless generic_object_definition
    options.keys.each do |k|
      unless property_attribute_defined?(k)
        raise ActiveModel::UnknownAttributeError.new(self, k)
      end
    end
    options.each { |k, v| custom_attribute_setter(k.to_s, v) }
  end

  private

  def method_missing(method_name, *args)
    m = method_name.to_s.chomp("=")
    super unless property_attribute_defined?(m)
    method_name.to_s.end_with?('=') ? custom_attribute_setter(m, args.first) : custom_attribute_getter(m)
  end

  def respond_to_missing?(method_name, _include_private = false)
    return true if property_attribute_defined?(method_name.to_s.chomp('='))
    super
  end

  def custom_attribute_getter(name)
    found = custom_attributes.detect { |ca| ca.name == name }
    found ? generic_object_definition.type_cast(name, found.value) : nil
  end

  def custom_attribute_setter(name, value)
    ca = custom_attributes.detect { |ca| ca.name == name }
    ca ? ca.write_attribute(:value, value.to_s) : custom_attributes.new(:name => name, :value => value.to_s)
  end

  def ca_attribute_for_inspect(value)
    if value.kind_of?(String) && value.length > 50
      "#{value[0, 50]}...".inspect
    elsif value.kind_of?(Date) || value.kind_of?(Time)
      %("#{value.to_s(:db)}")
    else
      value.inspect
    end
  end
end
