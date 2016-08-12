class GenericObjectDefinition < ApplicationRecord
  TYPE_MAP = {
    :boolean  => ActiveModel::Type::Boolean.new,
    :datetime => ActiveModel::Type::DateTime.new,
    :float    => ActiveModel::Type::Float.new,
    :integer  => ActiveModel::Type::Integer.new,
    :string   => ActiveModel::Type::String.new,
    :time     => ActiveModel::Type::Time.new
  }.freeze

  FEATURES = %w(attribute association).freeze

  serialize :properties, Hash

  has_one   :picture, :dependent => :destroy, :as => :resource
  has_many  :generic_objects

  validates :name, :presence => true, :uniqueness => true
  validate  :validate_property_attributes,
            :validate_property_associations,
            :validate_property_name_unique

  before_validation :set_default_properties
  before_validation :normalize_property_attributes,
                    :normalize_property_associations

  before_destroy    :check_not_in_use

  def create_object(options)
    GenericObject.create!({:generic_object_definition => self}.merge(options))
  end

  FEATURES.each do |feature|
    define_method("defined_property_#{feature}s") do
      return errors[:properties] if properties_changed? && !valid?
      properties["#{feature}s".to_sym]
    end

    define_method("property_#{feature}_defined?") do |attr|
      send("defined_property_#{feature}s").try(:key?, attr.to_s)
    end
  end

  def property_defined?(attr)
    property_attribute_defined?(attr) || property_association_defined?(attr)
  end

  def property_getter(attr, val)
    return type_cast(attr, val) if property_attribute_defined?(attr)
    return get_associations(attr, val) if property_association_defined?(attr)
  end

  def type_cast(attr, value)
    TYPE_MAP.fetch(defined_property_attributes[attr]).cast(value)
  end

  def properties=(props)
    props.reverse_merge!(:attributes => {}, :associations => {})
    super
  end

  private

  def get_associations(attr, values)
    defined_property_associations[attr].constantize.where(:id => values).to_a
  end

  def normalize_property_attributes
    props = properties.symbolize_keys

    properties[:attributes] = props[:attributes].each_with_object({}) do |(name, type), hash|
      hash[name.to_s] = type.to_sym
    end
  end

  def normalize_property_associations
    props = properties.symbolize_keys

    properties[:associations] = props[:associations].each_with_object({}) do |(name, type), hash|
      hash[name.to_s] = type.to_s.classify
    end
  end

  def validate_property_attributes
    properties[:attributes].each do |name, type|
      errors[:properties] << "attribute [#{name}] is not of a recognized type: [#{type}]" unless TYPE_MAP.key?(type.to_sym)
    end
  end

  def validate_property_associations
    properties[:associations].each do |name, klass|
      begin
        klass.constantize
      rescue NameError
        errors[:properties] << "association [#{name}] is not of a valid model: [#{klass}]"
      end
    end
  end

  def validate_property_name_unique
    common = properties[:attributes].keys & properties[:associations].keys
    errors[:properties] << "property name has to be unique: [#{common.join(",")}]" unless common.blank?
  end

  def check_not_in_use
    return true if generic_objects.empty?
    errors[:base] << "Cannot delete the definition while it is referenced by some generic objects"
    throw :abort
  end

  def set_default_properties
    self.properties = {:attributes => {}, :associations => {}} unless properties.present?
  end
end
