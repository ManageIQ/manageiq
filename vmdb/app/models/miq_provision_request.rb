class MiqProvisionRequest < MiqRequest
  alias_attribute :vm_template,    :source
  alias_attribute :provision_type, :request_type
  alias_attribute :miq_provisions, :miq_request_tasks

  include ReportableMixin

  TASK_DESCRIPTION  = 'VM Provisioning'
  SOURCE_CLASS_NAME = 'VmOrTemplate'
  REQUEST_TYPES     = %w{ template clone_to_vm clone_to_template }
  ACTIVE_STATES     = %w{ migrated } + base_class::ACTIVE_STATES

  validates_inclusion_of :request_type,   :in => REQUEST_TYPES,                          :message => "should be #{REQUEST_TYPES.join(", ")}"
  validates_inclusion_of :request_state,
                         :in      => %w(pending provisioned finished) + ACTIVE_STATES,
                         :message => "should be pending, #{ACTIVE_STATES.join(", ")}, provisioned, or finished"
  validates_presence_of  :source_id,      :message => "must have valid template"
  validate               :must_have_valid_vm
  validate               :must_have_user

  default_value_for :options,      :number_of_vms => 1
  default_value_for :request_type, REQUEST_TYPES.first
  default_value_for :message,      "#{TASK_DESCRIPTION} - Request Created"
  default_value_for(:src_vm_id)    { |r| r.get_option(:src_vm_id) }
  default_value_for(:requester)    { |r| r.get_user }

  virtual_column :provision_type, :type => :string

  include MiqProvisionMixin
  include MiqProvisionQuotaMixin

  def self.request_task_class_from(attribs)
    source_id = MiqRequestMixin.get_option(:src_vm_id, nil, attribs['options'])
    vm_or_template = VmOrTemplate.find_by_id(source_id)
    raise MiqException::MiqProvisionError, "Unable to find source Template/Vm with id [#{source_id}]" if vm_or_template.nil?

    suffix = vm_or_template.class.model_suffix.dup

    case suffix
    when "Vmware"
      case MiqRequestMixin.get_option(:provision_type, nil, attribs['options'])
      when "pxe";        suffix << "ViaPxe"
      end
    when "Redhat"
      case MiqRequestMixin.get_option(:provision_type, nil, attribs['options'])
      when "iso";        suffix << "ViaIso"
      when "pxe";        suffix << "ViaPxe"
      end
    end

    "MiqProvision#{suffix}".constantize
  end

  def self.new_request_task(attribs)
    klass = request_task_class_from(attribs)
    klass.new(attribs)
  end

  def must_have_valid_vm
    errors.add(:vm_template, "must have valid VM (must be in vmdb)") if vm_template.nil?
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

  def my_zone
    source.my_zone
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

    prov.options[:environment] = "prod" # Set env to prod to get service levels
    svc  = prov.allowed(:service_level) # Get service levels
    return false if env.include?("prod") && svc.empty?  # Make sure we have at least one

    true
  end

  def src_vm_id
    self.source_id
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
end
