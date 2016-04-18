class GenericObject < ApplicationRecord
  belongs_to :generic_object_definition
  has_many   :custom_attributes, :as => :resource, :dependent => :destroy, :autosave => true

  validates :name, :presence => true, :uniqueness => true
  validate  :must_be_defined_attributes

  TYPE_MAP = {
    :boolean  => ActiveRecord::Type::Boolean.new,
    :datetime => ActiveRecord::Type::DateTime.new,
    :time     => ActiveRecord::Type::Time.new,
    :float    => ActiveRecord::Type::Float.new,
    :integer  => ActiveRecord::Type::Integer.new,
    :string   => ActiveRecord::Type::String.new,
  }.freeze

  def must_be_defined_attributes
    return errors.add(:base, "must specify a GenericObjectDefinition.") unless generic_object_definition

    found = custom_attributes.detect { |ca| !generic_object_definition.defined_attributes.include?(ca.name) }
    if found
      errors.add(:base, "#{found.name} is not defined in GenericObjectDefinition: #{generic_object_definition.defined_attributes.keys.join(", ")}.")
    end
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

  def method_missing(method_name, *args)
    m = method_name.to_s.chomp("=")
    super if generic_object_definition && !generic_object_definition.defined_attributes.include?(m)
    method_name.to_s.end_with?('=') ? custom_attribute_setter(m, args.first) : custom_attribute_getter(m)
  end

  def respond_to_missing?(method_name, *args)
    return true unless generic_object_definition
    generic_object_definition.defined_attributes.include?(method_name.to_s.chomp!("=")) || super
  end

  def property_attributes
    custom_attributes.each_with_object({}) { |ca, h| h[ca.name] = custom_attribute_getter(ca.name) if ca.id }
  end

  def property_attributes=(options)
    options.each { |k, v| custom_attribute_setter(k, v) }
  end

  private

  def custom_attribute_getter(name)
    @custom_attributes ||= custom_attributes
    found = @custom_attributes.detect { |ca| ca.name == name }
    found ? type_cast(found.name, found.value) : nil
  end

  def custom_attribute_setter(name, value)
    ca = custom_attributes.find_by(:name => name)
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

  def type_cast(attr_name, value)
    TYPE_MAP.fetch(generic_object_definition.defined_attributes[attr_name].to_sym).cast(value)
  end
end
