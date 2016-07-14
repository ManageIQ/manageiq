class GenericObject < ApplicationRecord
  belongs_to :generic_object_definition

  validates :name, :presence => true

  delegate :property_attribute_defined?, :type_cast, :to => :generic_object_definition, :allow_nil => true

  def initialize(attributes = {})
    # generic_object_definition will be set first since hash iteration is based on the order of key insertion
    attributes = (attributes || {}).symbolize_keys
    attributes = attributes.slice(:generic_object_definition).merge(attributes.except(:generic_object_definition))
    super
  end

  def properties=(options)
    raise "generic_object_definition is nil" unless generic_object_definition
    options.keys.each do |k|
      unless property_attribute_defined?(k)
        raise ActiveModel::UnknownAttributeError.new(self, k)
      end
    end
    options.each { |k, v| property_attribute_setter(k.to_s, v) }
  end

  def properties
    super.each_with_object({}) { |(k, v), h| h[k] = type_cast(k, v) }
  end

  private

  def method_missing(method_name, *args)
    m = method_name.to_s.chomp("=")
    super unless property_attribute_defined?(m)
    method_name.to_s.end_with?('=') ? property_attribute_setter(m, args.first) : property_attribute_getter(m)
  end

  def respond_to_missing?(method_name, _include_private = false)
    return true if property_attribute_defined?(method_name.to_s.chomp('='))
    super
  end

  def property_attribute_getter(name)
    type_cast(name, read_attribute(:properties)[name])
  end

  def property_attribute_setter(name, value)
    write_attribute(:properties, read_attribute(:properties).merge!(name => type_cast(name, value)))
  end
end
