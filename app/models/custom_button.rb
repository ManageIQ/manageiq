class CustomButton < ApplicationRecord
  has_one :resource_action, :as => :resource, :dependent => :destroy, :autosave => true

  serialize :options
  serialize :visibility_expression
  serialize :enablement_expression
  serialize :visibility

  validates :applies_to_class, :presence => true
  validates :name, :description, :uniqueness => {:scope => [:applies_to_class, :applies_to_id]}, :presence => true
  validates :guid, :uniqueness => true, :presence => true

  include UuidMixin
  acts_as_miq_set_member

  TYPES = { "default"          => "Default",
            "ansible_playbook" => "Ansible Playbook"}.freeze

  PLAYBOOK_METHOD = "Order_Ansible_Playbook".freeze

  BUTTON_CLASSES = [
    AvailabilityZone,
    CloudNetwork,
    CloudObjectStoreContainer,
    CloudSubnet,
    CloudTenant,
    CloudVolume,
    ContainerGroup,
    ContainerImage,
    ContainerNode,
    ContainerProject,
    ContainerTemplate,
    ContainerVolume,
    EmsCluster,
    ExtManagementSystem,
    GenericObject,
    Host,
    LoadBalancer,
    MiqGroup,
    MiqTemplate,
    NetworkRouter,
    OrchestrationStack,
    SecurityGroup,
    Service,
    Storage,
    Switch,
    Tenant,
    User,
    Vm,
  ].freeze

  def self.buttons_for(other, applies_to_id = nil)
    if other.kind_of?(Class)
      applies_to_class = other.base_model.name
    elsif other.kind_of?(String)
      applies_to_class = other
    else
      raise _("Instance has no id") if other.id.nil?
      applies_to_class = other.class.base_model.name
      applies_to_id    = other.id
    end

    where(:applies_to_class => applies_to_class, :applies_to_id => applies_to_id)
  end

  def expanded_serializable_hash
    serializable_hash.tap do |button_hash|
      button_hash[:resource_action] = resource_action.serializable_hash if resource_action
    end
  end

  def applies_to
    klass = applies_to_class.constantize
    applies_to_id.nil? ? klass : klass.find_by(:id => applies_to_id)
  end

  def applies_to=(other)
    if other.kind_of?(Class)
      self.applies_to_class = other.base_model.name
      self.applies_to_id    = nil
    elsif other.kind_of?(String)
      self.applies_to_class = other
      self.applies_to_id    = nil
    else
      raise _("Instance has no id") if other.id.nil?
      self.applies_to_class = other.class.base_model.name
      self.applies_to_id    = other.id
    end
  end

  def invoke(target, source = nil)
    args = resource_action.automate_queue_hash(target, {}, User.current_user)

    publish_event(source, target, args)
    MiqQueue.put(queue_opts(target, args))
  end

  def publish_event(source, target, args)
    CustomButtonEvent.create(
      :event_type => 'button.trigger.start',
      :message    => 'Custom button launched',
      :source     => source,
      :target     => target,
      :username   => args[:username],
      :user_id    => args[:user_id],
      :group_id   => args[:miq_group_id],
      :tenant_id  => args[:tenant_id],
      :full_data  => {
        :args                 => args,
        :automate_entry_point => resource_action.ae_path,
        :button_id            => id,
        :button_name          => name
      }
    )
  end

  def queue_opts(target, args)
    {
      :class_name  => 'MiqAeEngine',
      :method_name => 'deliver',
      :args        => [args],
      :role        => 'automate',
      :zone        => target.try(:my_zone),
      :priority    => MiqQueue::HIGH_PRIORITY,
    }
  end

  def invoke_async(target, source = nil)
    task_opts = {
      :action => "Calling automate for user #{userid}",
      :userid => User.current_user
    }

    args = resource_action.automate_queue_hash(target, {}, User.current_user)

    publish_event(source, target, args)
    MiqTask.generic_action_with_callback(task_opts, queue_opts(target, args))
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
    resource_action || build_resource_action
  end

  def evaluate_enablement_expression_for(object)
    return true unless enablement_expression
    return false if enablement_expression && !object # list
    enablement_expression.lenient_evaluate(object)
  end

  def evaluate_visibility_expression_for(object)
    return true unless visibility_expression
    return false if visibility_expression && !object # object == nil, method is called for list of objects
    visibility_expression.lenient_evaluate(object)
  end

  # End - Helper methods to support moving automate columns to resource_actions table

  def self.parse_uri(uri)
    _scheme, _userinfo, _host, _port, _registry, path, _opaque, query, fragment = MiqAeEngine::MiqAeUri.split(uri)
    return path, MiqAeEngine::MiqAeUri.query2hash(query), fragment
  end

  def self.button_classes
    BUTTON_CLASSES.collect(&:name)
  end

  def visible_for_current_user?
    return false unless visibility.key?(:roles)
    visibility[:roles].include?(User.current_user.miq_user_role_name) || visibility[:roles].include?("_ALL_")
  end

  def self.get_user(user)
    user = User.find_by_userid(user) if user.kind_of?(String)
    raise _("Unable to find user '%{user}'") % {:user => user} if user.nil?
    user
  end

  def copy(options = {})
    options[:guid] = SecureRandom.uuid
    options.each_with_object(dup) { |(k, v), button| button.send("#{k}=", v) }.tap(&:save!)
  end

  def self.display_name(number = 1)
    n_('Button', 'Buttons', number)
  end

  def open_url?
    options[:open_url] == true
  end
end
