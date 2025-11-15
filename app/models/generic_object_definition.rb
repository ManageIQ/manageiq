class GenericObjectDefinition < ApplicationRecord
  include YamlImportExportMixin
  include ImportExport

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

  CONSTRAINT_TYPES = {
    :required   => [:boolean, :datetime, :float, :integer, :string, :time],
    :min        => [:integer, :float, :datetime, :time],
    :max        => [:integer, :float, :datetime, :time],
    :min_length => [:string],
    :max_length => [:string],
    :enum       => [:integer, :string],
    :format     => [:string]
  }.freeze

  FEATURES = %w[attribute attribute_constraint association method].freeze
  REG_ATTRIBUTE_NAME = /\A[a-z][a-zA-Z_0-9]*\z/
  REG_METHOD_NAME    = /\A[a-z][a-zA-Z_0-9]*[!?]?\z/
  ALLOWED_ASSOCIATION_TYPES = (MiqReport.reportable_models + %w[GenericObject]).freeze

  serialize :properties, :type => Hash

  include CustomActionsMixin

  has_one   :picture, :dependent => :destroy, :as => :resource
  has_many  :generic_objects

  validates :name, :presence => true, :uniqueness_when_changed => true
  validate  :validate_property_attributes,
            :validate_property_attribute_constraints,
            :validate_property_associations,
            :validate_property_methods,
            :validate_property_name_unique,
            :validate_supported_property_features

  before_validation :set_default_properties
  before_validation :normalize_property_attributes,
                    :normalize_property_attribute_constraints,
                    :normalize_property_associations,
                    :normalize_property_methods

  before_destroy    :check_not_in_use

  virtual_total :generic_objects_count, :generic_objects

  FEATURES.each do |feature|
    define_method(:"property_#{feature}s") do
      return errors[:properties] if properties_changed? && !valid?

      properties["#{feature}s".to_sym]
    end

    define_method(:"property_#{feature}_defined?") do |attr|
      attr = attr.to_s
      return property_methods.include?(attr) if feature == 'method'

      send(:"property_#{feature}s").key?(attr)
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

    get_objects_of_association(attr, val) if property_association_defined?(attr)
  end

  def type_cast(attr, value)
    TYPE_MAP.fetch(property_attributes[attr.to_s]).cast(value)
  end

  def properties=(props)
    props.reverse_merge!(:attributes => {}, :attribute_constraints => {}, :associations => {}, :methods => [])
    super
  end

  def add_property_attribute(name, type, constraints = {})
    properties[:attributes][name.to_s] = type.to_sym
    properties[:attribute_constraints][name.to_s] = constraints if constraints.present?
    save!
  end

  def delete_property_attribute(name)
    transaction do
      generic_objects.find_each { |o| o.delete_property(name) }

      properties[:attributes].delete(name.to_s)
      properties[:attribute_constraints].delete(name.to_s)
      save!
    end
  end

  def add_property_attribute_constraint(name, constraint)
    name = name.to_s
    raise "attribute [#{name}] is not defined" unless property_attribute_defined?(name)

    properties[:attribute_constraints][name] = constraint
    save!
  end

  def delete_property_attribute_constraint(name)
    properties[:attribute_constraints].delete(name.to_s)
    save!
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

  def normalize_property_attribute_constraints
    props = properties.symbolize_keys

    properties[:attribute_constraints] = props[:attribute_constraints].each_with_object({}) do |(name, constraints), hash|
      hash[name.to_s] = constraints
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
      errors.add(:properties, "attribute [#{name}] is not of a recognized type: [#{type}]") unless TYPE_MAP.key?(type.to_sym)
      errors.add(:properties, "invalid attribute name: [#{name}]") unless REG_ATTRIBUTE_NAME.match?(name)
    end
  end

  def validate_property_attribute_constraints
    properties[:attribute_constraints].each do |attr_name, constraints|
      # Check if the attribute exists
      unless properties[:attributes].key?(attr_name)
        errors.add(:properties, "constraint defined for non-existent attribute: [#{attr_name}]")
        next
      end

      attr_type = properties[:attributes][attr_name].to_sym

      # Validate constraints is a hash
      unless constraints.is_a?(Hash)
        errors.add(:properties, "constraints for attribute [#{attr_name}] must be a hash")
        next
      end

      constraints.each do |constraint_type, constraint_value|
        constraint_type_sym = constraint_type.to_sym

        # Check if constraint type is valid
        unless CONSTRAINT_TYPES.key?(constraint_type_sym)
          errors.add(:properties, "invalid constraint type [#{constraint_type}] for attribute [#{attr_name}]")
          next
        end

        # Check if constraint type is applicable to attribute type
        unless CONSTRAINT_TYPES[constraint_type_sym].include?(attr_type)
          errors.add(:properties, "constraint [#{constraint_type}] is not applicable to attribute type [#{attr_type}] for attribute [#{attr_name}]")
          next
        end

        # Validate constraint values
        validate_constraint_value(attr_name, attr_type, constraint_type_sym, constraint_value)
      end
    end
  end

  def validate_constraint_value(attr_name, attr_type, constraint_type, value)
    case constraint_type
    when :required
      unless [true, false].include?(value)
        errors.add(:properties, "constraint 'required' must be true or false for attribute [#{attr_name}]")
      end
    when :min, :max
      if attr_type == :integer && !value.is_a?(Integer)
        errors.add(:properties, "constraint '#{constraint_type}' must be an integer for attribute [#{attr_name}]")
      elsif attr_type == :float && !value.is_a?(Numeric)
        errors.add(:properties, "constraint '#{constraint_type}' must be a number for attribute [#{attr_name}]")
      elsif [:datetime, :time].include?(attr_type) && !value.is_a?(String) && !value.is_a?(Time) && !value.is_a?(DateTime)
        errors.add(:properties, "constraint '#{constraint_type}' must be a valid time/datetime for attribute [#{attr_name}]")
      end
    when :min_length, :max_length
      unless value.is_a?(Integer) && value > 0
        errors.add(:properties, "constraint '#{constraint_type}' must be a positive integer for attribute [#{attr_name}]")
      end
    when :enum
      validate_enum_constraint(attr_name, attr_type, value)
    when :format
      unless value.is_a?(Regexp) || (value.is_a?(String) && valid_regex?(value))
        errors.add(:properties, "constraint 'format' must be a valid regular expression for attribute [#{attr_name}]")
      end
    end
  end

  def valid_regex?(string)
    Regexp.new(string)
    true
  rescue RegexpError
    false
  end

  def validate_property_associations
    invalid_models = properties[:associations].values - ALLOWED_ASSOCIATION_TYPES
    errors.add(:properties, "invalid models for association: [#{invalid_models.join(",")}]") unless invalid_models.empty?

    properties[:associations].each do |name, _klass|
      errors.add(:properties, "invalid association name: [#{name}]") unless REG_ATTRIBUTE_NAME.match?(name)
    end
  end

  def validate_property_methods
    properties[:methods].each do |name|
      errors.add(:properties, "invalid method name: [#{name}]") unless REG_METHOD_NAME.match?(name)
    end
  end

  def validate_property_name_unique
    common = property_keywords.group_by(&:to_s).select { |_k, v| v.size > 1 }.collect(&:first)
    errors.add(:properties, "property name has to be unique: [#{common.join(",")}]") if common.present?
  end

  def validate_supported_property_features
    if properties.keys.any? { |f| !f.to_s.singularize.in?(FEATURES) }
      errors.add(:properties, "only these features are supported: [#{FEATURES.join(", ")}]")
    end
  end

  def property_keywords
    properties[:attributes].keys + properties[:associations].keys + properties[:methods]
  end

  def check_not_in_use
    return true if generic_objects.empty?

    errors.add(:base, "Cannot delete the definition while it is referenced by some generic objects")
    throw :abort
  end

  def set_default_properties
    self.properties = {:attributes => {}, :attribute_constraints => {}, :associations => {}, :methods => []} unless properties.present?
  end

  private

  def validate_enum_constraint(attr_name, attr_type, value)
    unless value.is_a?(Array) && value.any?
      errors.add(:properties, "constraint 'enum' must be a non-empty array for attribute [#{attr_name}]")
      return
    end

    if value.any?(&:nil?)
      errors.add(:properties, "constraint 'enum' must not contain nil values for attribute [#{attr_name}]")
      return
    end

    if value.uniq.size != value.size
      errors.add(:properties, "constraint 'enum' contains duplicate values for attribute [#{attr_name}]")
    end

    # Existing type validation continues...
    if attr_type == :integer && !value.all? { |v| v.is_a?(Integer) }
      errors.add(:properties, "constraint 'enum' values must be integers for attribute [#{attr_name}]")
    elsif attr_type == :string && !value.all? { |v| v.is_a?(String) }
      errors.add(:properties, "constraint 'enum' values must be strings for attribute [#{attr_name}]")
    end
  end
end
