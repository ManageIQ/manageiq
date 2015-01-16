class Vm < VmOrTemplate
  SUBCLASSES = %w{
    VmInfra
    VmCloud
  }

  default_scope { where(:template => false) }

  include_concern 'Operations'

  def self.base_model
    Vm
  end

  def self.corresponding_model
    @corresponding_model ||= (self == Vm) ? MiqTemplate : "Template#{self.model_suffix}".constantize
  end
  class << self; alias corresponding_template_model corresponding_model; end

  def corresponding_model
    self.class.corresponding_model
  end
  alias corresponding_template_model corresponding_model

  def validate_remote_console_vmrc_support
    raise(MiqException::RemoteConsoleNotSupportedError, "VMRC remote console is not supported on #{self.vendor}.")
  end

  def self.find_all_by_mac_address_and_hostname_and_ipaddress(mac_address, hostname, ipaddress)
    return [] if mac_address.nil? && hostname.nil? && ipaddress.nil?

    include = [:vm_or_template]
    conds = [["hardwares.vm_or_template_id IS NOT NULL"]]
    if mac_address
      conds[0] << "guest_devices.address = ?"
      conds    << mac_address
      include  << :nics
    end
    if hostname
      conds[0] << "networks.hostname = ?"
      conds    << hostname
      include  << :networks
    end
    if ipaddress
      conds[0] << "networks.ipaddress = ?"
      conds    << ipaddress
      include  << :networks
    end
    conds[0] = "(#{conds[0].join(" AND ")})"

    Hardware.includes(include.uniq).where(conds).collect { |h|  h.vm_or_template.kind_of?(Vm) ? h.vm_or_template : nil}.compact
  end

  def running_processes
    log_header = "MIQ(#{self.class.name}#running_processes)"
    pl = {}
    check = validate_collect_running_processes()
    unless check[:message].nil?
      $log.warn "#{log_header} #{check[:message]}"
      return pl
    end

    begin
      require 'miq-wmi'
      cred = self.my_zone_obj.auth_user_pwd(:windows_domain)
      self.ipaddresses.each do |ipaddr|
        break unless pl.blank?
        $log.info "#{log_header} Running processes for VM:[#{self.id}:#{self.name}]  IP:[#{ipaddr}] Logon:[#{cred[0]}]"
        begin
          wmi = WMIHelper.connectServer(ipaddr, *cred)
          pl = MiqProcess.process_list_all(wmi) unless wmi.nil?
        rescue => wmi_err
          $log.warn "#{log_header} #{wmi_err}"
        end
        $log.info "#{log_header} Running processes for VM:[#{self.id}:#{self.name}]  Count:[#{pl.length}]"
      end
    rescue => err
      $log.log_backtrace(err)
    end
    pl
  end

end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
Vm::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
