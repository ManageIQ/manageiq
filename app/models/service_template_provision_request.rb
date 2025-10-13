class ServiceTemplateProvisionRequest < MiqRequest
  TASK_DESCRIPTION  = N_('Service_Template_Provisioning')
  SOURCE_CLASS_NAME = 'ServiceTemplate'
  ACTIVE_STATES     = %w[migrated] + base_class::ACTIVE_STATES
  SERVICE_ORDER_CLASS = '::ServiceOrderCart'.freeze

  validates_inclusion_of :request_state,  :in => %w[pending finished] + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  after_create :process_service_order

  virtual_has_one :picture
  virtual_has_one :service_template
  virtual_has_one :provision_dialog
  virtual_has_one :user

  default_value_for(:source_id)    { |r| r.get_option(:src_id) }
  default_value_for :source_type,  SOURCE_CLASS_NAME
  default_value_for :process,      false

  delegate :picture, :to => :service_template, :allow_nil => true

  alias_method :user, :get_user
  include MiqProvisionQuotaMixin

  def service_template
    source
  end

  def service_template=(object)
    self.source = object
  end

  def process_service_order
    if cancel_requested?
      do_cancel
      return
    end

    case options[:cart_state]
    when ServiceOrder::STATE_ORDERED
      ServiceOrder.order_immediately(self, requester)
    when ServiceOrder::STATE_CART
      ServiceOrder.add_to_cart(self, requester)
    end
  end

  def my_role(action = nil)
    action == :create_request_tasks ? 'automate' : 'ems_operations'
  end

  def my_zone
    @my_zone ||= dialog_zone || service_template.my_zone
  end

  def provision_dialog
    request_dialog("Provision")
  end

  def requested_task_idx
    [0]
  end

  def customize_request_task_attributes(req_task_attrs, idx)
    req_task_attrs['options'][:pass] = idx

    configuration_script_id = resource_action&.configuration_script_id
    return if configuration_script_id.nil?

    # If we are provisioning a "generic" service_template
    #   then we want to directly run embedded workflows
    # Otherwise
    #   then we want to keep running automate at the top level, and run the embedded workflow as a child task
    if source.prov_type == "generic" || source.prov_type == "generic_terraform_template"
      req_task_attrs['options'][:configuration_script_payload_id] = configuration_script_id
    else
      req_task_attrs['options'][:parent_configuration_script_payload_id] = configuration_script_id
    end
  end

  def resource_action
    resource_action_id = options.dig(:workflow_settings, :resource_action_id)
    return if resource_action_id.nil?

    ResourceAction.find(resource_action_id)
  end

  def originating_controller
    "service"
  end

  def my_records
    "#{self.class::SOURCE_CLASS_NAME}:#{get_option(:src_id)}"
  end

  def process_on_create?
    false
  end
end
