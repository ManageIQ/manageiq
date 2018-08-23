class Vm < VmOrTemplate
  default_scope { where(:template => false) }
  has_one :container_deployment, :through => :container_deployment_node
  has_one :container_deployment_node

  virtual_has_one :supported_consoles, :class_name => "Hash"

  extend InterRegionApiMethodRelay
  include CustomActionsMixin
  include CiFeatureMixin

  include_concern 'Operations'

  def self.base_model
    Vm
  end

  def self.corresponding_model
    if self == Vm
      MiqTemplate
    else
      parent::Template
    end
  end
  class << self; alias_method :corresponding_template_model, :corresponding_model; end

  delegate :corresponding_model, :to => :class
  alias_method :corresponding_template_model, :corresponding_model

  def validate_remote_console_vmrc_support
    raise(MiqException::RemoteConsoleNotSupportedError,
          _("VMRC remote console is not supported on %{vendor}.") % {:vendor => vendor})
  end

  def add_to_service(service)
    service.add_resource!(self)
  end

  def enforce_single_service_parent?
    true
  end

  def self.find_all_by_mac_address_and_hostname_and_ipaddress(mac_address, hostname, ipaddress)
    return [] if mac_address.blank? && hostname.blank? && ipaddress.blank?

    include = [:vm_or_template]
    references = []
    conds = [["hardwares.vm_or_template_id IS NOT NULL"]]
    if mac_address
      conds[0] << "guest_devices.address = ?"
      conds << mac_address
      include << :nics
      references << :guest_devices
    end
    if hostname
      conds[0] << "networks.hostname = ?"
      conds << hostname
      include << :networks
      references << :networks
    end
    if ipaddress
      conds[0] << "networks.ipaddress = ?"
      conds << ipaddress
      include << :networks
      references << :networks
    end
    conds[0] = "(#{conds[0].join(" AND ")})"

    Hardware.includes(include.uniq)
      .references(references.uniq)
      .where(conds)
      .collect { |h|  h.vm_or_template.kind_of?(Vm) ? h.vm_or_template : nil }.compact
  end

  def running_processes
    pl = {}
    check = validate_collect_running_processes
    unless check[:message].nil?
      _log.warn(check[:message].to_s)
      raise check[:message].to_s
    end

    begin
      require 'win32/miq-wmi'
      cred = my_zone_obj.auth_user_pwd(:windows_domain)
      ipaddresses.each do |ipaddr|
        break unless pl.blank?
        _log.info("Running processes for VM:[#{id}:#{name}]  IP:[#{ipaddr}] Logon:[#{cred[0]}]")
        begin
          wmi = WMIHelper.connectServer(ipaddr, *cred)
          pl = MiqProcess.process_list_all(wmi) unless wmi.nil?
        rescue => wmi_err
          _log.warn(wmi_err.to_s)
        end
        _log.info("Running processes for VM:[#{id}:#{name}]  Count:[#{pl.length}]")
      end
    rescue => err
      _log.log_backtrace(err)
    end
    pl
  end

  def remote_console_url=(url, user_id)
    SystemConsole.where(:vm_id => id).each(&:destroy)
    console = SystemConsole.create!(
      :vm_id      => id,
      :user       => User.find_by(:userid => user_id),
      :protocol   => 'url',
      :url        => url,
      :url_secret => SecureRandom.hex
    )
    console.id
  end

  def supported_consoles
    {
      :spice   => spice_support,
      :vnc     => vnc_support,
      :vmrc    => vmrc_support,
      :webmks  => webmks_support,
      :cockpit => cockpit_support
    }
  end

  def validate_v2v_migration
    return TransformationMapping::VM_INACTIVE unless active?

    vm_as_resources = ServiceResource.where(:resource => self).includes(:service_template).where(:service_templates => {:type => "ServiceTemplateTransformationPlan"})

    # VM has not been migrated before
    return TransformationMapping::VM_VALID if vm_as_resources.blank?

    return TransformationMapping::VM_MIGRATED if vm_as_resources.any? { |rsc| rsc.status == ServiceResource::STATUS_COMPLETED }

    # VM failed in previous migration
    vm_as_resources.all? { |rsc| rsc.status == ServiceResource::STATUS_FAILED } ? TransformationMapping::VM_VALID : TransformationMapping::VM_IN_OTHER_PLAN
  end

  def self.display_name(number = 1)
    n_('VM and Instance', 'VMs and Instances', number)
  end

  private

  def vnc_support
    {
      :visible => supports_vnc_console?,
      :enabled => supports_launch_vnc_console?,
      :message => unsupported_reason(:launch_vnc_console)
    }
  end

  def webmks_support
    {
      :visible => supports_mks_console?,
      :enabled => supports_launch_mks_console?,
      :message => unsupported_reason(:launch_mks_console)
    }
  end

  def vmrc_support
    {
      :visible => supports_vnc_console?,
      :enabled => supports_launch_vmrc_console?,
      :message => unsupported_reason(:launch_vmrc_console)
    }
  end

  def spice_support
    {
      :visible => supports_spice_console?,
      :enabled => supports_launch_spice_console?,
      :message => unsupported_reason(:launch_spice_console)
    }
  end

  def cockpit_support
    {
      :visible => supports_cockpit_console?,
      :enabled => supports_launch_cockpit?,
      :message => unsupported_reason(:launch_cockpit)
    }
  end

  def console_supports_type?(console_type)
    Settings.server.remote_console_type.upcase == console_type.upcase ? console_supported?(console_type) : false
  end
end
