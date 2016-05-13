class GenericObjectDefinition < ApplicationRecord
  TYPE_MAP = {
    :boolean  => ActiveRecord::Type::Boolean.new,
    :datetime => ActiveRecord::Type::DateTime.new,
    :time     => ActiveRecord::Type::Time.new,
    :float    => ActiveRecord::Type::Float.new,
    :integer  => ActiveRecord::Type::Integer.new,
    :string   => ActiveRecord::Type::String.new,
  }.freeze

  validates :name, :presence => true, :uniqueness => true

  serialize :properties, Hash

  has_one   :picture, :dependent => :destroy, :as => :resource
  has_many  :generic_objects

  before_destroy :check_not_in_use

  def defined_property_attributes
    properties[:attributes]
  end

  def property_attribute_defined?(attr)
    defined_property_attributes.try(:key?, attr.to_s)
  end

  def properties=(props)
    props = props.symbolize_keys
    if props.key?(:attributes)
      props[:attributes] = props[:attributes].each_with_object({}) do |(name, type), hash|
        raise ArgumentError, "#{type} is not a recognized type" unless TYPE_MAP.key?(type.to_sym)
        hash[name.to_s] = type.to_sym
      end
    end
    super
  end

  def type_cast(attr_name, value)
    TYPE_MAP.fetch(defined_property_attributes[attr_name]).cast(value)
  end

  private

  def check_not_in_use
    return true if generic_objects.empty?
    errors[:base] << "Cannot delete the definition while it is referenced by some generic objects"
    throw :abort
  end
end
