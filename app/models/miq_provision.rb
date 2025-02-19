class MiqProvision < MiqProvisionTask
  include MiqProvisionMixin
  include Automate
  include CustomAttributes
  include Description
  include Genealogy
  include PostInstallCallback
  include Helper
  include Iso
  include Naming
  include OptionsHelper
  include Ownership
  include Pxe
  include Retirement
  include Service
  include StateMachine
  include Tagging

  alias_attribute :provision_type,        :request_type # Legacy provisioning support
  before_create :set_template_and_networking

  virtual_belongs_to :miq_provision_request  # Legacy provisioning support
  virtual_belongs_to :vm
  virtual_belongs_to :vm_template
  virtual_column     :placement_auto, :type => :boolean

  scope :with_miq_request_id, ->(request_id) { where(:miq_request_id => request_id) }

  CLONE_SYNCHRONOUS     = false
  CLONE_TIME_LIMIT      = 4.hours

  # Legacy provisioning support
  def miq_provision_request
    miq_request
  end

  def miq_provision_request=(object)
    self.miq_request = object
  end

  def vm
    destination
  end

  def vm=(object)
    self.destination = object
  end

  def vm_template
    source
  end

  def vm_template=(object)
    self.source = object
  end

  def self.base_model
    MiqProvision
  end

  def statemachine_task_status
    if %w[finished provisioned].include?(state)
      status.to_s.downcase == "error" || vm.nil? ? "error" : "ok"
    else
      "retry"
    end
  end

  def set_template_and_networking
    self.source = get_source

    set_static_ip_address
    set_dns_domain
  end

  def deliver_to_automate(*)
    super("vm_provision", my_zone)
  end

  def execute_queue
    super(:zone        => my_zone,
          :queue_name  => my_queue_name,
          :msg_timeout => CLONE_SYNCHRONOUS ? CLONE_TIME_LIMIT : MiqQueue::TIMEOUT)
  end

  def my_queue_name
    source.ext_management_system&.queue_name_for_ems_operations
  end

  def placement_auto
    get_option(:force_placement_auto) || get_option(:placement_auto)
  end

  def after_request_task_create
    update_vm_name(get_next_vm_name, :update_request => false)
  end

  def update_vm_name(new_name, update_request: true)
    new_name = self.class.get_vm_full_name(new_name, self, true)
    options[:vm_target_name]     = new_name
    options[:vm_target_hostname] = get_hostname(new_name)

    update(:description => self.class.get_description(self, new_name), :options => options)
    miq_request.try(:update_description_from_tasks) if update_request
  end

  def after_ae_delivery(ae_result)
    _log.info("ae_result=#{ae_result.inspect}")

    return if ae_result == 'retry'
    return if miq_request.state == 'finished'

    if ae_result == 'ok'
      update_and_notify_parent(:state => "finished", :status => "Ok", :message => "#{request_class::TASK_DESCRIPTION} completed")
    else
      update_and_notify_parent(:state => "finished", :status => "Error")
    end
  end

  def workflow_inputs
    options
  end

  def self.get_description(prov_obj, vm_name)
    request_type = prov_obj.options[:request_type]
    title = case request_type
            when :clone_to_vm       then _("Clone")
            when :clone_to_template then _("Publish")
            else _("Provision")
            end

    _("%{title} from [%{name}] to [%{vm_name}]") % {:title   => title,
                                                    :name    => prov_obj.vm_template.name,
                                                    :vm_name => vm_name}
  end

  def self.display_name(number = 1)
    n_('Provision', 'Provisions', number)
  end
end
