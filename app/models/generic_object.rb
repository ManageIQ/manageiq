class GenericObject < ApplicationRecord
  belongs_to :generic_object_definition

  validates :name, :presence => true

  delegate :property_attribute_defined?, :property_association_defined?,
           :property_defined?, :type_cast, :defined_property_associations,
           :defined_property_associations, :to => :generic_object_definition, :allow_nil => true

  def initialize(attributes = {})
    # generic_object_definition will be set first since hash iteration is based on the order of key insertion
    attributes = (attributes || {}).symbolize_keys
    attributes = attributes.slice(:generic_object_definition).merge(attributes.except(:generic_object_definition))
    super
  end

  def property_attributes=(options)
    raise "generic_object_definition is nil" unless generic_object_definition
    options.keys.each do |k|
      unless property_attribute_defined?(k)
        raise ActiveModel::UnknownAttributeError.new(self, k)
      end
    end
    options.each { |k, v| property_setter(k.to_s, v) }
  end

  def property_attributes
    properties.select { |k, _| property_attribute_defined?(k) }.each_with_object({}) do |(k, _), h|
      h[k] = property_getter(k)
    end
  end

  def inspect
    attributes_as_string = (self.class.column_names - ["properties"]).collect do |name|
      "#{name}: #{attribute_for_inspect(name)}"
    end

    attributes_as_string += ["attributes: #{property_attributes}"]
    attributes_as_string += ["associations: #{defined_property_associations.keys}"]

    prefix = Kernel.instance_method(:inspect).bind(self).call.split(' ', 2).first
    "#{prefix} #{attributes_as_string.join(", ")}>"
  end

  private

  # The properties column contains raw data that are converted during read/write.
  # Don't want the user access it directly.
  #
  def properties
    super
  end

  def properties=(options)
    super
  end

  def method_missing(method_name, *args)
    m = method_name.to_s.chomp("=")
    super unless property_defined?(m)
    method_name.to_s.end_with?('=') ? property_setter(m, args.first) : property_getter(m)
  end

  def respond_to_missing?(method_name, _include_private = false)
    return true if property_defined?(method_name.to_s.chomp('='))
    super
  end

  def property_getter(name)
    generic_object_definition.property_getter(name, properties[name])
  end

  def property_setter(name, value)
    val =
      if property_attribute_defined?(name)
        # property attribute is of single value, for now
        type_cast(name, value)
      elsif property_association_defined?(name)
        # property association is of multiple values
        value.select { |v| v.kind_of?(defined_property_associations[name].constantize) }.uniq.map(&:id)
      end

    self.properties = properties.merge(name => val)
  end
end
