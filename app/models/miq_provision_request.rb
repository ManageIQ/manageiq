class MiqProvisionRequest < MiqRequest
  alias_attribute :vm_template,    :source
  alias_attribute :provision_type, :request_type
  alias_attribute :miq_provisions, :miq_request_tasks
  alias_attribute :src_vm_id,      :source_id
  alias_attribute :src_type,       :source_type

  delegate :my_zone, :to => :source

  TASK_DESCRIPTION  = 'VM Provisioning'.freeze
  SOURCE_CLASS_NAME = "Vm".freeze
  ACTIVE_STATES     = %w(migrated) + base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,
                         :in      => %w(pending provisioned finished) + ACTIVE_STATES,
                         :message => "should be pending, #{ACTIVE_STATES.join(", ")}, provisioned, or finished"
  validates_presence_of  :source_id, :message => "must have valid provisioning source"
  validate               :must_have_valid_source
  validate               :must_have_user

  default_value_for :options,      :number_of_vms => 1
  default_value_for(:src_vm_id)    { |r| r.get_option(:src_vm_id) }
  default_value_for(:src_type)     { |r| r.get_option(:src_type) || "VmOrTemplate" }

  virtual_column :provision_type, :type => :string

  include MiqProvisionMixin
  include MiqProvisionQuotaMixin

  def self.request_task_class_from(attribs)
    source_id = MiqRequestMixin.get_option(:source_id, nil, attribs['options'])
    source_type = MiqRequestMixin.get_option(:source_type, nil, attribs['options'])
    source_id ||= MiqRequestMixin.get_option(:src_vm_id, nil, attribs['options'])
    source_type ||= MiqRequestMixin.get_option(:src_type, nil, attribs['options'])
    provisioning_source = MiqProvisionSource.get_provisioning_request_source(source_id, source_type)
    raise MiqException::MiqProvisionError, "Unable to find source #{source_type} with id [#{source_id}]" if provisioning_source.nil?

    via = MiqRequestMixin.get_option(:provision_type, nil, attribs['options'])
    manager = provisioning_source.ext_management_system.top_level_manager
    manager.class.provision_class(via)
  end

  def self.new_request_task(attribs)
    klass = request_task_class_from(attribs)
    klass.new(attribs)
  end

  def must_have_valid_source
    errors.add(:source, "must have valid provisioning source") if source.nil?
  end

  def set_description(force = false)
    prov_description = nil
    if description.nil? || force == true
      prov_description = MiqProvision.get_description(self, MiqProvision.get_next_vm_name(self, false))
    end
    # Capture self.options after running 'get_next_vm_name' method since automate may update the object
    attrs = {:options => options.merge(:delivered_on => nil)}
    attrs[:description] = prov_description unless prov_description.nil?
    update_attributes(attrs)
  end

  def post_create_request_tasks
    return unless requested_task_idx.length == 1
    update_attributes(:description => miq_request_tasks.first.description)
  end

  def my_role
    'ems_operations'
  end

  def requested_task_idx
    (1..get_option(:number_of_vms).to_i).to_a
  end

  def customize_request_task_attributes(req_task_attrs, idx)
    req_task_attrs['options'][:pass] = idx
  end

  # methods to be implemented in resolution
  #
  def self.ready?(userid)
    # must have at least one dept, env
    # if env includes prod must have at least one service_level
    prov = MiqProvision.new(:userid => userid)
    dept = prov.allowed(:department)
    env  = prov.allowed(:environment)

    return false if dept.empty? || env.empty?

    prov.options[:environment] = "prod"                # Set env to prod to get service levels
    svc = prov.allowed(:service_level)                 # Get service levels
    return false if env.include?("prod") && svc.empty? # Make sure we have at least one

    true
  end

  def src_vm_id=(value)
    self.source_id   = value
    self.source_type = 'VmOrTemplate'
  end

  def target
    :vms
  end

  def vms
    miq_provisions.collect(&:vm).compact
  end

  def originating_controller
    "vm"
  end

  def template_valid?
    validate_template[:valid]
  end

  def template_valid_error_message
    validate_template[:message]
  end

  def validate_template
    return {
      :valid   => false,
      :message => "Unable to find #{source_type} with Id [#{source_id}]"
    } if source.nil?

    return {
      :valid   => false,
      :message => "#{source_type} <#{source.name}> with Id <#{source.id}> is archived and cannot be used with provisioning."
    } if source.try(:archived?)

    return {
      :valid   => false,
      :message => "#{source_type} <#{source.name}> with Id <#{source.id}> is orphaned and cannot be used with provisioning."
    } if source.try(:orphaned?)

    {:valid => true, :message => nil}
  end

  def event_name(mode)
    "vm_provision_request_#{mode}"
  end

  def my_records
    "#{SOURCE_CLASS_NAME}:#{source_id.inspect}"
  end
end
