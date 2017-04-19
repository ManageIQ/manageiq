class Vm < VmOrTemplate
  default_scope { where(:template => false) }
  has_one :container_deployment, :through => :container_deployment_node
  has_one :container_deployment_node
  has_many :custom_button_sets, :as => :owner, :dependent => :destroy
  virtual_has_one :custom_actions, :class_name => "Hash"
  virtual_has_one :custom_action_buttons, :class_name => "Array"

  extend InterRegionApiMethodRelay

  include_concern 'Operations'

  def self.base_model
    Vm
  end

  def self.include_descendant_classes_in_expressions?
    true
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
      _log.warn check[:message].to_s
      return pl
    end

    begin
      require 'win32/miq-wmi'
      cred = my_zone_obj.auth_user_pwd(:windows_domain)
      ipaddresses.each do |ipaddr|
        break unless pl.blank?
        _log.info "Running processes for VM:[#{id}:#{name}]  IP:[#{ipaddr}] Logon:[#{cred[0]}]"
        begin
          wmi = WMIHelper.connectServer(ipaddr, *cred)
          pl = MiqProcess.process_list_all(wmi) unless wmi.nil?
        rescue => wmi_err
          _log.warn wmi_err.to_s
        end
        _log.info "Running processes for VM:[#{id}:#{name}]  Count:[#{pl.length}]"
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

  def custom_actions
    generic_button_group = CustomButton.buttons_for("Vm").select { |button| !button.parent.nil? }
    custom_button_sets_with_generics = custom_button_sets + generic_button_group.map(&:parent).uniq.flatten
    {
      :buttons       => custom_buttons.collect(&:expanded_serializable_hash),
      :button_groups => custom_button_sets_with_generics.collect do |button_set|
        button_set.serializable_hash.merge(:buttons => button_set.children.collect(&:expanded_serializable_hash))
      end
    }
  end

  def custom_action_buttons
    custom_buttons + custom_button_sets.collect(&:children).flatten
  end

  def custom_buttons
    CustomButton.buttons_for("Vm").select { |button| button.parent.nil? } + direct_custom_buttons
  end

  def direct_custom_buttons
    CustomButton.buttons_for(self).select { |b| b.parent.nil? }
  end
end
