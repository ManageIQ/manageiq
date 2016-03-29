class ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow < ManageIQ::Providers::InfraManager::ProvisionWorkflow
  def self.default_dialog_file
    'miq_provision_dialogs'
  end

  def self.default_pre_dialog_file
    'miq_provision_dialogs_pre'
  end

  def self.encrypted_options_fields
    super + [:sysprep_password, :sysprep_domain_password]
  end

  def supports_pxe?
    get_value(@values[:provision_type]).to_s == 'pxe'
  end

  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, {'platform' => 'vmware'})
  end

  def allowed_provision_types(_options = {})
    {
      "vmware" => "VMware",
      "pxe"    => "PXE"
    }
  end

  SYSPREP_TIMEZONES = [
    ['000', "(GMT-12:00) International Date Line West"],
    ['001', "(GMT-11:00) Midway Island, Samoa"],
    ['002', "(GMT-10:00) Hawaii"],
    ['003', "(GMT-09:00) Alaska"],
    ['004', "(GMT-08:00) Pacific Time (US and Canada); Tijuana"],
    ['010', "(GMT-07:00) Mountain Time (US and Canada)"],
    ['013', "(GMT-07:00) Chihuahua, La Paz, Mazatlan"],
    ['015', "(GMT-07:00) Arizona"],
    ['020', "(GMT-06:00) Central Time (US and Canada)"],
    ['025', "(GMT-06:00) Saskatchewan"],
    ['030', "(GMT-06:00) Guadalajara, Mexico City, Monterrey"],
    ['033', "(GMT-06:00) Central America"],
    ['035', "(GMT-05:00) Eastern Time (US and Canada)"],
    ['040', "(GMT-05:00) Indiana (East)"],
    ['045', "(GMT-05:00) Bogota, Lima, Quito"],
    ['050', "(GMT-04:00) Atlantic Time (Canada)"],
    ['055', "(GMT-04:00) Caracas, La Paz"],
    ['056', "(GMT-04:00) Santiago"],
    ['060', "(GMT-03:30) Newfoundland and Labrador"],
    ['065', "(GMT-03:00) Brasilia"],
    ['070', "(GMT-03:00) Buenos Aires, Georgetown"],
    ['073', "(GMT-03:00) Greenland"],
    ['075', "(GMT-02:00) Mid-Atlantic"],
    ['080', "(GMT-01:00) Azores"],
    ['083', "(GMT-01:00) Cape Verde Islands"],
    ['085', "(GMT-00:00) Greenwich Mean Time : Dublin, Edinburgh, Lisbon, London"],
    ['090', "(GMT-00:00) Casablanca, Monrovia"],
    ['095', "(GMT+01:00) Belgrade, Bratislava, Budapest, Ljubljana, Prague"],
    ['100', "(GMT+01:00) Sarajevo, Skopje, Warsaw, Zagreb"],
    ['105', "(GMT+01:00) Brussels, Copenhagen, Madrid, Paris"],
    ['110', "(GMT+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna"],
    ['113', "(GMT+01:00) West Central Africa"],
    ['115', "(GMT+02:00) Bucharest"],
    ['120', "(GMT+02:00) Cairo"],
    ['125', "(GMT+02:00) Helsinki, Kiev, Riga, Sofia, Tallinn, Vilnius"],
    ['130', "(GMT+02:00) Athens, Istanbul, Minsk"],
    ['135', "(GMT+02:00) Jerusalem"],
    ['140', "(GMT+02:00) Harare, Pretoria"],
    ['145', "(GMT+03:00) Moscow, St. Petersburg, Volgograd"],
    ['150', "(GMT+03:00) Kuwait, Riyadh"],
    ['155', "(GMT+03:00) Nairobi"],
    ['158', "(GMT+03:00) Baghdad"],
    ['160', "(GMT+03:30) Tehran"],
    ['165', "(GMT+04:00) Abu Dhabi, Muscat"],
    ['170', "(GMT+04:00) Baku, Tbilisi, Yerevan"],
    ['175', "(GMT+04:30) Kabul"],
    ['180', "(GMT+05:00) Ekaterinburg"],
    ['185', "(GMT+05:00) Islamabad, Karachi, Tashkent"],
    ['190', "(GMT+05:30) Chennai, Kolkata, Mumbai, New Delhi"],
    ['193', "(GMT+05:45) Kathmandu"],
    ['195', "(GMT+06:00) Astana, Dhaka"],
    ['200', "(GMT+06:00) Sri Jayawardenepura"],
    ['201', "(GMT+06:00) Almaty, Novosibirsk"],
    ['203', "(GMT+06:30) Yangon (Rangoon)"],
    ['205', "(GMT+07:00) Bangkok, Hanoi, Jakarta"],
    ['207', "(GMT+07:00) Krasnoyarsk"],
    ['210', "(GMT+08:00) Beijing, Chongqing, Hong Kong SAR, Urumqi"],
    ['215', "(GMT+08:00) Kuala Lumpur, Singapore"],
    ['220', "(GMT+08:00) Taipei"],
    ['225', "(GMT+08:00) Perth"],
    ['227', "(GMT+08:00) Irkutsk, Ulaanbaatar"],
    ['230', "(GMT+09:00) Seoul"],
    ['235', "(GMT+09:00) Osaka, Sapporo, Tokyo"],
    ['240', "(GMT+09:00) Yakutsk"],
    ['245', "(GMT+09:30) Darwin"],
    ['250', "(GMT+09:30) Adelaide"],
    ['255', "(GMT+10:00) Canberra, Melbourne, Sydney"],
    ['260', "(GMT+10:00) Brisbane"],
    ['265', "(GMT+10:00) Hobart"],
    ['270', "(GMT+10:00) Vladivostok"],
    ['275', "(GMT+10:00) Guam, Port Moresby"],
    ['280', "(GMT+11:00) Magadan, Solomon Islands, New Caledonia"],
    ['285', "(GMT+12:00) Fiji Islands, Kamchatka, Marshall Islands"],
    ['290', "(GMT+12:00) Auckland, Wellington"],
    ['300', "(GMT+13:00) Nuku'alofa"]
  ]

  def get_timezones(_options = {})
    SYSPREP_TIMEZONES.collect(&:reverse)
  end

  def self.provider_model
    ManageIQ::Providers::Vmware::InfraManager
  end

  def update_field_visibility
    options = {}
    vm = load_ar_obj(get_source_vm)
    unless vm.nil?
      vm_hardware_version = vm.hardware.virtual_hw_version rescue nil
      options[:read_only_fields] = [:cores_per_socket] if vm_hardware_version.to_i < 7
    end

    super(options)
  end

  def available_vlans(options = {})
    vlans = super

    # Remove certain networks
    vlans.delete_if { |_k, v| v.in?(['Service Console', 'VMkernel']) }

    unless @vlan_options[:dvs] == false
      rails_logger('allowed_dvs', 0)
      vlans_dvs = allowed_dvs(@vlan_options, hosts)
      vlans.merge!(vlans_dvs)
      rails_logger('allowed_dvs', 1)
    end

    vlans
  end

  def allowed_dvs(_options = {}, hosts = nil)
    @dvs_ems_connect_ok ||= {}
    @dvs_by_host ||= {}
    switches = {}
    src = get_source_and_targets
    return switches if src.blank?

    hosts ||= get_selected_hosts(src)

    # Find if we need to connect to the EMS to collect a host's dvs
    missing_hosts = hosts.reject { |h| @dvs_by_host.key?(h.id) }
    unless missing_hosts.blank?
      begin
        st = Time.now
        return switches if src[:ems] && @dvs_ems_connect_ok[src[:ems].id] == false
        vim = load_ar_obj(src[:ems]).connect
        missing_hosts.each { |dest_host| @dvs_by_host[dest_host.id] = get_host_dvs(dest_host, vim) }
      rescue
        @dvs_ems_connect_ok[src[:ems].id] = false if src[:ems]
        return switches
      ensure
        vim.disconnect if vim rescue nil
        _log.info "Network DVS collection completed in [#{Time.now - st}] seconds"
      end
    end
    create_unified_pg(@dvs_by_host, hosts)
  end

  def get_host_dvs(dest_host, vim)
    switches = {}
    dvs = vim.queryDvsConfigTarget(vim.sic.dvSwitchManager, dest_host.ems_ref_obj, nil) rescue nil

    # List the names of the non-uplink portgroups.
    unless dvs.nil? || dvs.distributedVirtualPortgroup.nil?
      nupga = vim.applyFilter(dvs.distributedVirtualPortgroup, 'uplinkPortgroup' => 'false')
      nupga.each { |nupg| switches[URI.decode(nupg.portgroupName)] = [URI.decode(nupg.switchName)] }
    end

    switches
  end

  def create_unified_pg(dvs_by_host, hosts)
    all_pgs = Hash.new { |h, k| h[k] = [] }
    hosts.each do |host|
      pgs = dvs_by_host[host.id]
      next if pgs.blank?
      pgs.each { |k, v| all_pgs[k].concat(v) }
    end

    all_pgs.each_with_object({}) do |(pg, switch), switches|
      switches["dvs_#{pg}"] = "#{pg} (#{switch.uniq.sort.join('/')})"
    end
  end
end
