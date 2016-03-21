class MiqProvision < MiqProvisionTask
  include MiqProvisionMixin
  include_concern 'Automate'
  include_concern 'CustomAttributes'
  include_concern 'Description'
  include_concern 'Genealogy'
  include_concern 'PostInstallCallback'
  include_concern 'Helper'
  include_concern 'Iso'
  include_concern 'Naming'
  include_concern 'OptionsHelper'
  include_concern 'Ownership'
  include_concern 'Pxe'
  include_concern 'Retirement'
  include_concern 'Service'
  include_concern 'StateMachine'
  include_concern 'Tagging'

  alias_attribute :miq_provision_request, :miq_request   # Legacy provisioning support
  alias_attribute :provision_type,        :request_type  # Legacy provisioning support
  alias_attribute :vm,                    :destination
  alias_attribute :vm_template,           :source

  before_create :set_template_and_networking

  virtual_belongs_to :miq_provision_request  # Legacy provisioning support
  virtual_belongs_to :vm
  virtual_belongs_to :vm_template
  virtual_column     :placement_auto, :type => :boolean
  virtual_column     :provision_type, :type => :string  # Legacy provisioning support

  CLONE_SYNCHRONOUS     = false
  CLONE_TIME_LIMIT      = 4.hours
  SUPPORTED_EMS_CLASSES = %w( ManageIQ::Providers::Vmware::InfraManager
                              ManageIQ::Providers::Redhat::InfraManager
                              ManageIQ::Providers::Amazon::CloudManager
                              ManageIQ::Providers::Openstack::CloudManager
                              ManageIQ::Providers::Microsoft::InfraManager
                              ManageIQ::Providers::Google::CloudManager
                              ManageIQ::Providers::Azure::CloudManager)

  def self.base_model
    MiqProvision
  end

  def set_template_and_networking
    self.source = get_source

    set_static_ip_address
    set_dns_domain
  end

  def deliver_to_automate
    super("vm_provision", my_zone)
  end

  def execute_queue
    super(:zone        => my_zone,
          :msg_timeout => CLONE_SYNCHRONOUS ? CLONE_TIME_LIMIT : MiqQueue::TIMEOUT)
  end

  def placement_auto
    get_option(:placement_auto)
  end

  def after_request_task_create
    vm_name                      = get_next_vm_name
    options[:vm_target_name]     = vm_name
    options[:vm_target_hostname] = get_hostname(vm_name)
    self.description             = self.class.get_description(self, vm_name)
    save
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
end
