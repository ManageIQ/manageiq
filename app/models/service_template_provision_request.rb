class ServiceTemplateProvisionRequest < MiqRequest
  TASK_DESCRIPTION  = 'Service_Template_Provisioning'
  SOURCE_CLASS_NAME = 'ServiceTemplate'
  ACTIVE_STATES     = %w( migrated ) + base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,  :in => %w( pending finished ) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  virtual_has_one :picture
  virtual_has_one :service_template
  virtual_has_one :provision_dialog
  virtual_has_one :user

  default_value_for(:source_id)    { |r| r.get_option(:src_id) }
  default_value_for :source_type,  SOURCE_CLASS_NAME

  def user
    get_user
  end

  def my_role
    'ems_operations'
  end

  def my_zone
    nil
  end

  def picture
    st = service_template
    st.picture if st.present?
  end

  def service_template
    ServiceTemplate.find_by_id(source_id)
  end

  def provision_dialog
    st = service_template
    return {} if st.blank?
    ra = st.resource_actions.find_by_action("Provision")
    dialog = ResourceActionWorkflow.new(options[:dialog], get_user, ra, {}).dialog
    DialogSerializer.new.serialize(Array[dialog]).first
  end

  def requested_task_idx
    requested_count = 1
    (0..requested_count - 1).to_a
  end

  def customize_request_task_attributes(req_task_attrs, idx)
    req_task_attrs['options'][:pass] = idx
  end

  def my_records
    "#{self.class::SOURCE_CLASS_NAME}:#{get_option(:src_id)}"
  end
end
