class GenericObjectDefinition < ApplicationRecord
  include YAMLImportExportMixin
  include_concern 'ImportExport'

  TYPE_MAP = {
    :boolean  => ActiveModel::Type::Boolean.new,
    :datetime => ActiveModel::Type::DateTime.new,
    :float    => ActiveModel::Type::Float.new,
    :integer  => ActiveModel::Type::Integer.new,
    :string   => ActiveModel::Type::String.new,
    :time     => ActiveModel::Type::Time.new
  }.freeze

  TYPE_NAMES = {
    :boolean  => N_('Boolean'),
    :datetime => N_('Date/Time'),
    :float    => N_('Float'),
    :integer  => N_('Integer'),
    :string   => N_('String'),
    :time     => N_('Time')
  }.freeze

  FEATURES = %w(attribute association method).freeze
  REG_ATTRIBUTE_NAME = /\A[a-z][a-zA-Z_0-9]*\z/
  REG_METHOD_NAME    = /\A[a-z][a-zA-Z_0-9]*[!?]?\z/
  ALLOWED_ASSOCIATION_TYPES = (MiqReport.reportable_models + %w(GenericObject)).freeze

  serialize :properties, Hash

  include CustomActionsMixin

  has_one   :picture, :dependent => :destroy, :as => :resource
  has_many  :generic_objects

  validates :name, :presence => true, :uniqueness_when_changed => true
  validate  :validate_property_attributes,
            :validate_property_associations,
            :validate_property_methods,
            :validate_property_name_unique,
            :validate_supported_property_features

  before_validation :set_default_properties
  before_validation :normalize_property_attributes,
                    :normalize_property_associations,
                    :normalize_property_methods

  before_destroy    :check_not_in_use

  delegate :count, :to => :generic_objects, :prefix => true, :allow_nil => false
  virtual_column :generic_objects_count, :type => :integer

  FEATURES.each do |feature|
    define_method("property_#{feature}s") do
      return errors[:properties] if properties_changed? && !valid?
      properties["#{feature}s".to_sym]
    end

    define_method("property_#{feature}_defined?") do |attr|
      attr = attr.to_s
      return property_methods.include?(attr) if feature == 'method'
      send("property_#{feature}s").key?(attr)
    end
  end

  def property_defined?(attr)
    property_attribute_defined?(attr) || property_association_defined?(attr) || property_method_defined?(attr)
  end

  def create_object(options)
    GenericObject.create!({:generic_object_definition => self}.merge(options))
  end

  # To query based on GenericObject AR attributes and property attributes
  #   find_objects(:name => "TestLoadBalancer", :uid => '0001', :prop_attr_1 => 10, :prop_attr_2 => true)
  #
  # To query based on property associations. The array can be a partial list, but must contain only AR ids.
  #   find_objects(:vms => [23, 26])
  #
  def find_objects(options)
    dup = options.stringify_keys
    ar_options   = dup.extract!(*(GenericObject.column_names - ["properties"]))
    json_options = dup.extract!(*(property_attributes.keys + property_associations.keys))

    unless dup.empty?
      err_msg = _("[%{attrs}]: not searchable for Generic Object of %{name}") % {:attrs => dup.keys.join(", "),
                                                                                 :name  => name}
      _log.error(err_msg)
      raise err_msg
    end

    generic_objects.where(ar_options).where("properties @> ?", json_options.to_json)
  end

  def property_getter(attr, val)
    return type_cast(attr, val) if property_attribute_defined?(attr)
    return get_objects_of_association(attr, val) if property_association_defined?(attr)
  end

  def type_cast(attr, value)
    TYPE_MAP.fetch(property_attributes[attr.to_s]).cast(value)
  end

  def properties=(props)
    props.reverse_merge!(:attributes => {}, :associations => {}, :methods => [])
    super
  end

  def add_property_attribute(name, type)
    properties[:attributes][name.to_s] = type.to_sym
    save!
  end

  def delete_property_attribute(name)
    transaction do
      generic_objects.find_each { |o| o.delete_property(name) }

      properties[:attributes].delete(name.to_s)
      save!
    end
  end

  def add_property_association(name, type)
    type = type.to_s.classify
    raise "invalid model for association: [#{type}]" unless type.in?(ALLOWED_ASSOCIATION_TYPES)

    properties[:associations][name.to_s] = type
    save!
  end

  def delete_property_association(name)
    transaction do
      generic_objects.find_each { |o| o.delete_property(name) }

      properties[:associations].delete(name.to_s)
      save!
    end
  end

  def add_property_method(name)
    return if properties[:methods].include?(name.to_s)

    properties[:methods] << name.to_s
    save!
  end

  def delete_property_method(name)
    properties[:methods].delete(name.to_s)
    save!
  end

  def generic_custom_buttons
    CustomButton.buttons_for("GenericObject")
  end

  def self.display_name(number = 1)
    n_('Generic Object Class', 'Generic Object Classes', number)
  end

  private

  def get_objects_of_association(attr, values)
    property_associations[attr.to_s].constantize.where(:id => values).to_a
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

  def normalize_property_methods
    props = properties.symbolize_keys
    properties[:methods] = props[:methods].collect(&:to_s)
  end

  def validate_property_attributes
    properties[:attributes].each do |name, type|
      errors[:properties] << "attribute [#{name}] is not of a recognized type: [#{type}]" unless TYPE_MAP.key?(type.to_sym)
      errors[:properties] << "invalid attribute name: [#{name}]" unless REG_ATTRIBUTE_NAME =~ name
    end
  end

  def validate_property_associations
    invalid_models = properties[:associations].values - ALLOWED_ASSOCIATION_TYPES
    errors[:properties] << "invalid models for association: [#{invalid_models.join(",")}]" unless invalid_models.empty?

    properties[:associations].each do |name, _klass|
      errors[:properties] << "invalid association name: [#{name}]" unless REG_ATTRIBUTE_NAME =~ name
    end
  end

  def validate_property_methods
    properties[:methods].each do |name|
      errors[:properties] << "invalid method name: [#{name}]" unless REG_METHOD_NAME =~ name
    end
  end

  def validate_property_name_unique
    common = property_keywords.group_by(&:to_s).select { |_k, v| v.size > 1 }.collect(&:first)
    errors[:properties] << "property name has to be unique: [#{common.join(",")}]" unless common.blank?
  end

  def validate_supported_property_features
    if properties.keys.any? { |f| !f.to_s.singularize.in?(FEATURES) }
      errors[:properties] << "only these features are supported: [#{FEATURES.join(", ")}]"
    end
  end

  def property_keywords
    properties[:attributes].keys + properties[:associations].keys + properties[:methods]
  end

  def check_not_in_use
    return true if generic_objects.empty?
    errors[:base] << "Cannot delete the definition while it is referenced by some generic objects"
    throw :abort
  end

  def set_default_properties
    self.properties = {:attributes => {}, :associations => {}, :methods => []} unless properties.present?
  end
end
