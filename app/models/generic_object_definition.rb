class GenericObjectDefinition < ApplicationRecord
  TYPE_MAP = {
    :boolean  => ActiveModel::Type::Boolean.new,
    :datetime => ActiveModel::Type::DateTime.new,
    :float    => ActiveModel::Type::Float.new,
    :integer  => ActiveModel::Type::Integer.new,
    :string   => ActiveModel::Type::String.new,
    :time     => ActiveModel::Type::Time.new
  }.freeze

  validates :name, :presence => true, :uniqueness => true

  serialize :properties, Hash

  has_one   :picture, :dependent => :destroy, :as => :resource
  has_many  :generic_objects

  before_destroy :check_not_in_use

  def create_object(options)
    GenericObject.create!({:generic_object_definition => self}.merge(options))
  end

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
