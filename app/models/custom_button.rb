class CustomButton < ApplicationRecord
  has_one       :resource_action, :as => :resource, :dependent => :destroy, :autosave => true

  serialize :options
  serialize :applies_to_exp
  serialize :visibility

  validates :applies_to_class, :presence => true
  validates :name, :description, :uniqueness => {:scope => [:applies_to_class, :applies_to_id]}, :presence => true
  validates :guid, :uniqueness => true, :presence => true

  include UuidMixin
  acts_as_miq_set_member

  BUTTON_CLASSES = [
    Vm,
    Host,
    ExtManagementSystem,
    Storage,
    EmsCluster,
    MiqTemplate,
    Service
  ]

  def self.buttons_for(other, applies_to_id = nil)
    if other.kind_of?(Class)
      applies_to_class = other.base_model.name
      applies_to_id    = applies_to_id
    elsif other.kind_of?(String)
      applies_to_class = other
      applies_to_id    = applies_to_id
    else
      raise "Instance has no id" if other.id.nil?
      applies_to_class = other.class.base_model.name
      applies_to_id    = other.id
    end

    where(:applies_to_class => applies_to_class, :applies_to_id => applies_to_id)
  end

  def expanded_serializable_hash
    button_hash = serializable_hash(:except => [:created_on, :updated_on])
    if resource_action
      button_hash[:resource_action] = resource_action.serializable_hash
    end
    button_hash
  end

  def applies_to
    klass = applies_to_class.constantize
    applies_to_id.nil? ? klass : klass.find_by_id(applies_to_id)
  end

  def applies_to=(other)
    if other.kind_of?(Class)
      self.applies_to_class = other.base_model.name
      self.applies_to_id    = nil
    elsif other.kind_of?(String)
      self.applies_to_class = other
      self.applies_to_id    = nil
    else
      raise "Instance has no id" if other.id.nil?
      self.applies_to_class = other.class.base_model.name
      self.applies_to_id    = other.id
    end
  end

  def invoke(target)
    args = resource_action.automate_queue_hash(target, {}, User.current_user)
    MiqQueue.put(
      :class_name  => 'MiqAeEngine',
      :method_name => 'deliver',
      :args        => [args],
      :role        => 'automate',
      :zone        => target.try(:my_zone),
      :priority    => MiqQueue::HIGH_PRIORITY,
    )
  end

  def to_export_xml(_options)
  end

  # Helper methods to support moving automate columns to resource_actions table
  def uri=(_value)
  end

  def uri
    resource_action.try(:ae_uri)
  end

  def uri_path=(value)
    ra = get_resource_action
    ra.ae_namespace, ra.ae_class, ra.ae_instance, _attr_name = MiqAeEngine::MiqAePath.split(value)
  end

  def uri_path
    get_resource_action.try(:ae_path)
  end

  def uri_message=(value)
    get_resource_action.ae_message = value
  end

  def uri_message
    get_resource_action.ae_message
  end

  def uri_attributes=(value)
    attrs = value.reject { |k, _v| MiqAeEngine::DEFAULT_ATTRIBUTES.include?(k) }
    get_resource_action.ae_attributes = attrs
  end

  def uri_attributes
    get_resource_action.ae_attributes
  end

  def uri_object_name
    get_resource_action.ae_instance
  end

  def get_resource_action
    return resource_action unless resource_action.nil?
    build_resource_action
  end
  # End - Helper methods to support moving automate columns to resource_actions table

  def self.parse_uri(uri)
    scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeEngine::MiqAeUri.split(uri)
    return path, MiqAeEngine::MiqAeUri.query2hash(query), fragment
  end

  def self.button_classes
    BUTTON_CLASSES.collect(&:name)
  end

  def self.name_to_button_class(name)
    BUTTON_CLASSES.find { |klass| klass.name == name }
  end

  def self.available_for_user(user, group)
    user = get_user(user)
    role = user.miq_user_role_name
    # Return all automation uri's that has his role or is allowed for all roles.
    all.to_a.select do |uri|
      uri.parent && uri.parent.name == group && uri.visibility.key?(:roles) && (uri.visibility[:roles].include?(role) || uri.visibility[:roles].include?("_ALL_"))
    end
  end

  def self.get_user(user)
    user = User.in_region.find_by_userid(user) if user.kind_of?(String)
    raise "Unable to find user '#{user}'" if user.nil?
    user
  end
end
