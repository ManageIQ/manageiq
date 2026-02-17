class GenericObject < ApplicationRecord
  acts_as_miq_taggable

  include ExternalUrlMixin

  virtual_has_one :custom_actions
  virtual_has_one :custom_action_buttons

  belongs_to :generic_object_definition
  has_one :picture, :through => :generic_object_definition
  has_many :custom_button_events, :foreign_key => :target_id, :dependent => :destroy

  validates :name, :presence => true
  before_validation :apply_default_values
  validate :validate_property_attribute_constraints

  delegate :property_attribute_defined?,
           :property_defined?,
           :type_cast,
           :property_association_defined?,
           :property_methods, :property_method_defined?,
           :to => :generic_object_definition, :allow_nil => true

  delegate :name, :to => :generic_object_definition, :prefix => true, :allow_nil => false
  virtual_column :generic_object_definition_name, :type => :string
  before_destroy :remove_go_from_all_related_services

  def initialize(attributes = {})
    # generic_object_definition will be set first since hash iteration is based on the order of key insertion
    attributes = (attributes || {}).symbolize_keys
    attributes = attributes.slice(:generic_object_definition).merge(attributes.except(:generic_object_definition))
    super
  end

  def custom_actions
    generic_object_definition&.custom_actions(self)
  end

  def custom_action_buttons
    generic_object_definition&.custom_action_buttons(self)
  end

  def property_attributes=(options)
    raise "generic_object_definition is nil" unless generic_object_definition

    options.keys.each do |k|
      unless property_attribute_defined?(k)
        raise ActiveModel::UnknownAttributeError.new(self, k)
      end
    end
    options.each { |k, v| _property_setter(k, v) }
  end

  def property_attributes
    properties.select { |k, _| property_attribute_defined?(k) }.each_with_object({}) do |(k, _), h|
      h[k] = _property_getter(k)
    end
  end

  def property_associations
    properties.select { |k, _| property_association_defined?(k) }.each_with_object({}) do |(k, _), h|
      h[k] = _property_getter(k)
    end
  end

  def delete_property(name)
    if !property_attribute_defined?(name) && !property_association_defined?(name)
      valid_property_names = generic_object_definition.property_attributes.keys + generic_object_definition.property_associations.keys
      raise "Invalid property [#{name}]: must be one of #{valid_property_names.join(", ")}"
    end

    _property_getter(name).tap do
      properties.delete(name.to_s)
      save!
    end
  end

  def add_to_property_association(name, objs)
    objs = [objs] unless objs.kind_of?(Array)
    name = name.to_s
    properties[name] ||= []

    klass = generic_object_definition.property_associations[name].constantize
    selected = objs.select { |obj| obj.kind_of?(klass) }
    properties[name] = (properties[name] + selected.pluck(:id)).uniq if selected
    save!
  end

  def delete_from_property_association(name, objs)
    objs = [objs] unless objs.kind_of?(Array)
    name = name.to_s
    properties[name] ||= []

    klass = generic_object_definition.property_associations[name].constantize
    selected = objs.select { |obj| obj.kind_of?(klass) }
    common_ids = properties[name] & selected.pluck(:id)
    properties[name] = properties[name] - common_ids
    return unless properties_changed?

    save!
    klass.where(:id => common_ids).to_a
  end

  def add_to_service(service)
    service.add_resource!(self)
  end

  def remove_from_service(service)
    service.remove_resource(self)
  end

  def inspect
    attributes_as_string = (self.class.column_names - ["properties"]).collect do |name|
      "#{name}: #{attribute_for_inspect(name)}"
    end

    attributes_as_string += ["attributes: #{property_attributes}"]
    attributes_as_string += ["associations: #{generic_object_definition.property_associations.keys}"]
    attributes_as_string += ["methods: #{property_methods}"]

    prefix = Kernel.instance_method(:inspect).bind_call(self).split(' ', 2).first
    "#{prefix} #{attributes_as_string.join(", ")}>"
  end

  def ae_user_identity(*args)
    @user, @group, @tenant = *args
    raise "A user is required to send calls to automate." unless @user

    @group  ||= @user.current_group
    @tenant ||= @user.current_tenant
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

    return _call_automate(m, *args) if property_method_defined?(m)

    if property_attribute_defined?(m) || property_association_defined?(m)
      return method_name.to_s.end_with?('=') ? _property_setter(m, args.first) : _property_getter(m)
    end

    super
  end

  def respond_to_missing?(method_name, _include_private = false)
    return true if property_defined?(method_name.to_s.chomp('='))

    super
  end

  def _property_getter(name)
    generic_object_definition.property_getter(name.to_s, properties[name.to_s])
  end

  def _property_setter(name, value)
    name = name.to_s

    val =
      if property_attribute_defined?(name)
        # property attribute is of single value, for now
        type_cast(name, value)
      elsif property_association_defined?(name)
        # property association is of multiple values
        value.select { |v| v.kind_of?(generic_object_definition.property_associations[name].constantize) }.uniq.map(&:id)
      end

    self.properties = properties.merge(name => val)
  end

  # the method parameters are passed into automate as a hash:
  # {:param_1 => 12, :param_1_type => "Vm", :param_2 => 14, :param_2_type => "Integer"}
  # the return value from automate is in $evm.root['method_result']
  def _call_automate(method_name, *args)
    @user ||= User.current_user
    @group ||= User.current_user.current_group
    @tenant ||= User.current_user.current_tenant
    raise "A user is required to send [#{method_name}] to automate." unless @user

    attrs = {:method_name => method_name}
    args.each_with_index do |item, idx|
      attrs["param_#{idx + 1}".to_sym] = item
      attrs["param_#{idx + 1}_type".to_sym] = item.class.name
    end

    options = {
      :object_type   => self.class.name,
      :object_id     => id,
      :instance_name => 'GenericObject',
      :user_id       => @user.id,
      :miq_group_id  => @group.id,
      :tenant_id     => @tenant.id,
      :attrs         => attrs
    }

    ws = MiqAeEngine.deliver(options)
    ws.root['method_result']
  end

  def remove_go_from_all_related_services
    ServiceResource.where(:resource => self).each do |resource|
      remove_from_service(resource.service) if resource.service
    end
  end

  def apply_default_values
    return unless generic_object_definition

    constraints = generic_object_definition.properties[:attribute_constraints] || {}
    
    constraints.each do |attr_name, attr_constraints|
      # Only apply default if attribute is not set and has a default value
      if properties[attr_name].nil? && attr_constraints.key?(:default)
        default_value = attr_constraints[:default]
        # Type cast the default value
        if property_attribute_defined?(attr_name)
          properties[attr_name] = type_cast(attr_name, default_value)
        end
      end
    end
  end

  def validate_property_attribute_constraints
    return unless generic_object_definition

    constraints = generic_object_definition.properties[:attribute_constraints] || {}
    attributes = generic_object_definition.properties[:attributes] || {}
    
    constraints.each do |attr_name, attr_constraints|
      # Get value from properties hash (where custom attributes are stored)
      value = properties[attr_name]
      attr_type = attributes[attr_name]
      
      # Skip validation if attribute is not set (nil) unless it's required
      next if value.nil? && !attr_constraints[:required]
      
      # Type checking for Hash and Array
      if attr_type == :hash && value.present? && !value.is_a?(Hash)
        errors.add(:properties, "attribute '#{attr_name}' must be a Hash")
        next
      end
      
      if attr_type == :array && value.present? && !value.is_a?(Array)
        errors.add(:properties, "attribute '#{attr_name}' must be an Array")
        next
      end
      
      attr_constraints.each do |constraint_type, constraint_value|
        # Skip default constraint in validation (it's applied in before_validation)
        next if constraint_type == :default
        validate_constraint(attr_name, value, constraint_type, constraint_value)
      end
    end
  end

  def validate_constraint(attr_name, value, constraint_type, constraint_value)
    case constraint_type
    when :required
      if constraint_value && (value.nil? || (value.is_a?(String) && value.strip.empty?))
        errors.add(:properties, "attribute '#{attr_name}' is required")
      end
    when :min
      if value.present? && value < constraint_value
        errors.add(:properties, "attribute '#{attr_name}' must be greater than or equal to #{constraint_value}")
      end
    when :max
      if value.present? && value > constraint_value
        errors.add(:properties, "attribute '#{attr_name}' must be less than or equal to #{constraint_value}")
      end
    when :min_length
      if value.present? && value.to_s.length < constraint_value
        errors.add(:properties, "attribute '#{attr_name}' must be at least #{constraint_value} characters long")
      end
    when :max_length
      if value.present? && value.to_s.length > constraint_value
        errors.add(:properties, "attribute '#{attr_name}' must be at most #{constraint_value} characters long")
      end
    when :enum
      if value.present? && !constraint_value.include?(value)
        errors.add(:properties, "attribute '#{attr_name}' must be one of: #{constraint_value.join(', ')}")
      end
    when :format
      if value.present?
        regex = constraint_value.is_a?(Regexp) ? constraint_value : Regexp.new(constraint_value)
        unless regex.match?(value.to_s)
          errors.add(:properties, "attribute '#{attr_name}' format is invalid")
        end
      end
    when :min_items
      if value.is_a?(Array) && value.size < constraint_value
        errors.add(:properties, "attribute '#{attr_name}' must have at least #{constraint_value} items")
      end
    when :max_items
      if value.is_a?(Array) && value.size > constraint_value
        errors.add(:properties, "attribute '#{attr_name}' must have at most #{constraint_value} items")
      end
    when :unique_items
      if constraint_value && value.is_a?(Array) && value.uniq.size != value.size
        errors.add(:properties, "attribute '#{attr_name}' must have unique items")
      end
    when :required_keys
      if value.is_a?(Hash)
        missing_keys = constraint_value.map(&:to_s) - value.keys.map(&:to_s)
        if missing_keys.any?
          errors.add(:properties, "attribute '#{attr_name}' is missing required keys: #{missing_keys.join(', ')}")
        end
      end
    when :allowed_keys
      if value.is_a?(Hash)
        extra_keys = value.keys.map(&:to_s) - constraint_value.map(&:to_s)
        if extra_keys.any?
          errors.add(:properties, "attribute '#{attr_name}' has disallowed keys: #{extra_keys.join(', ')}")
        end
      end
    end
  end
end
