class MiqProvisionRequest < MiqRequest
  alias_attribute :vm_template,    :source
  alias_attribute :provision_type, :request_type
  alias_attribute :miq_provisions, :miq_request_tasks
  alias_attribute :src_vm_id,      :source_id

  delegate :my_zone, :to => :source

  TASK_DESCRIPTION  = 'VM Provisioning'
  SOURCE_CLASS_NAME = 'Vm'
  ACTIVE_STATES     = %w(migrated) + base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,
                         :in      => %w(pending provisioned finished) + ACTIVE_STATES,
                         :message => "should be pending, #{ACTIVE_STATES.join(", ")}, provisioned, or finished"
  validates :source, :presence => true
  validate               :must_have_user

  default_value_for :options,      :number_of_vms => 1
  default_value_for(:src_vm_id)    { |r| r.get_option(:src_vm_id) }

  virtual_column :provision_type, :type => :string

  include MiqProvisionMixin
  include MiqProvisionQuotaMixin

  def self.request_task_class_from(attribs)
    source_id = MiqRequestMixin.get_option(:src_vm_id, nil, attribs['options'])
    vm_or_template = source_vm_or_template!(source_id)

    via = MiqRequestMixin.get_option(:provision_type, nil, attribs['options'])
    vm_or_template.ext_management_system.class.provision_class(via)
  end

  def self.source_vm_or_template!(source_id)
    vm_or_template = VmOrTemplate.find_by(:id => source_id)
    if vm_or_template.nil?
      raise MiqException::MiqProvisionError, "Unable to find source Template/Vm with id [#{source_id}]"
    end

    if vm_or_template.ext_management_system.nil?
      raise MiqException::MiqProvisionError, "Source Template/Vm with id [#{source_id}] has no EMS, unable to provision"
    end
    vm_or_template
  end

  def self.new_request_task(attribs)
    klass = request_task_class_from(attribs)
    klass.new(attribs)
  end

  def set_description(force = false)
    prov_description = nil
    if description.nil? || force == true
      prov_description = MiqProvision.get_description(self, MiqProvision.get_next_vm_name(self, false))
    end
    # Capture self.options after running 'get_next_vm_name' method since automate may update the object
    attrs = {:options => options.merge(:delivered_on => nil)}
    attrs[:description] = prov_description unless prov_description.nil?
    update(attrs)
  end

  def post_create_request_tasks
    update_description_from_tasks
  end

  def update_description_from_tasks
    return unless requested_task_idx.length == 1
    update(:description => miq_request_tasks.reload.first.description)
  end

  def my_role(_action = nil)
    'ems_operations'
  end

  def my_queue_name
    source.ext_management_system&.queue_name_for_ems_operations
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

    prov.options[:environment] = "prod" # Set env to prod to get service levels
    svc  = prov.allowed(:service_level) # Get service levels
    return false if env.include?("prod") && svc.empty?  # Make sure we have at least one

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
    return {:valid   => false,
            :message => "Unable to find VM with Id [#{source_id}]"
    } if source.nil?

    return {:valid   => false,
            :message => "VM/Template <#{source.name}> with Id <#{source.id}> is archived and cannot be used with provisioning."
    } if source.archived?

    return {:valid   => false,
            :message => "VM/Template <#{source.name}> with Id <#{source.id}> is orphaned and cannot be used with provisioning."
    } if source.orphaned?

    {:valid => true, :message => nil}
  end

  def event_name(mode)
    "vm_provision_request_#{mode}"
  end

  def my_records
    "#{SOURCE_CLASS_NAME}:#{source_id.inspect}"
  end
end
