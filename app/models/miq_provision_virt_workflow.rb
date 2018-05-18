class MiqProvisionVirtWorkflow < MiqProvisionWorkflow
  include_concern "DialogFieldValidation"

  def auto_placement_enabled?
    get_value(@values[:placement_auto])
  end

  def initialize(values, requester, options = {})
    initial_pass = values.blank?
    initial_pass = true if options[:initial_pass] == true
    instance_var_init(values, requester, options)

    # Check if the caller passed the source VM as part of the initial call
    if initial_pass == true
      src_vm_id = get_value(@values[:src_vm_id])
      unless src_vm_id.blank?
        vm = VmOrTemplate.find_by(:id => src_vm_id)
        @values[:src_vm_id] = [vm.id, vm.name] unless vm.blank?
      end
    end

    unless options[:skip_dialog_load] == true
      # If this is the first time we are called the values hash will be empty
      # Also skip if we are being called from a web-service
      @dialogs = get_pre_dialogs if initial_pass && options[:use_pre_dialog] != false
      if @dialogs.nil?
        @dialogs = get_dialogs
      else
        @running_pre_dialog = true if options[:use_pre_dialog] != false
      end
      normalize_numeric_fields unless @dialogs.nil?
    end

    password_helper(@values, false) # Decrypt passwords in the hash for the UI
    @last_vm_id = get_value(@values[:src_vm_id]) unless initial_pass == true

    return if options[:skip_dialog_load] == true

    set_default_values
    update_field_visibility

    if get_value(values[:service_template_request])
      show_dialog(:requester, :hide, "disabled")
      show_dialog(:purpose,   :hide, "disabled")
    end
  end

  def dialog_name_from_automate(message = 'get_dialog_name', extra_attrs = {})
    super(message, [:request_type, :source_type, :target_type], extra_attrs)
  end

  def make_request(request, values, requester = nil, auto_approve = false)
    if @running_pre_dialog == true
      continue_request(values)
      password_helper(values, true)
      return nil
    end

    if request
      request = request.kind_of?(MiqRequest) ? request : MiqRequest.find(request)
      request.src_vm_id = get_value(values[:src_vm_id])
    end

    super
  end

  def refresh_field_values(values)
    st = Time.now
    new_src = get_value(values[:src_vm_id])
    vm_changed = @last_vm_id != new_src

    # Note: This makes a copy of the values hash so we have a copy of the object to modify
    @values = values

    get_source_and_targets(true)

    # Update fields that should be updated when the Source VM changes
    if vm_changed
      set_on_vm_id_changed
      get_source_and_targets(true)
    end

    # @values gets modified during this call
    get_all_dialogs
    update_custom_spec
    values.merge!(@values)

    # Update the display flag for fields based on current settings
    update_field_visibility

    @last_vm_id = get_value(@values[:src_vm_id])
    _log.info("provision refresh completed in [#{Time.now - st}] seconds")
  rescue => err
    $log.log_backtrace(err)
    raise
  ensure
    @allowed_vlan_cache = nil
  end

  def custom_sysprep_timezone(field, data_value)
    set_value_from_list(:sysprep_timezone, field, "%03d" % data_value, @timezones)
  end

  def custom_sysprep_domain_name(field, data_value)
    set_value_from_list(:sysprep_domain_name, field, data_value, nil, true)
  end

  def set_on_vm_id_changed
    src = get_source_and_targets
    vm, ems = load_ar_obj(src[:vm]), src[:ems]

    clear_field_values(
      [:placement_host_name,
       :placement_ds_name,
       :placement_folder_name,
       :placement_cluster_name,
       :placement_rp_name,
       :linked_clone,
       :snapshot,
       :placement_dc_name]
    )

    if vm.nil?
      clear_field_values([:number_of_cpus, :number_of_sockets, :cores_per_socket, :vm_memory, :cpu_limit, :memory_limit, :cpu_reserve, :memory_reserve])
      vm_description = nil
      vlan = nil
      show_dialog(:customize, :show, "disabled")
    else
      if vm.ext_management_system.nil?
        raise _("Source VM [%{name}] does not belong to a Provider") % {:name => vm.name}
      end
      set_or_default_hardware_field_values(vm)

      # Record the nic/lan setting on the template for validation checks at provision time.
      @values[:src_vm_nics] = vm.hardware && vm.hardware.nics.collect(&:device_name).compact
      @values[:src_vm_lans] = vm.lans.collect(&:name).compact
      vlan = @values[:src_vm_lans].first
      vm_description = vm.description
      case vm.platform
      when 'linux', 'windows' then show_dialog(:customize, :show, "enabled")
      else                         show_dialog(:customize, :hide, "disabled")
      end

      # If the selected template switches EMS, update the value and invalidate the @ems_metadata_tree handle.
      if get_value(@values[:src_ems_id]) != ems.id
        @values[:src_ems_id] = [ems.id, ems.name]
        @ems_metadata_tree = nil
      end
    end

    # Update VM description
    fields do |fn, f, _, _|
      case fn
      when :src_vm_id
        f[:notes] = vm_description
      when :vlan
        get_field(:vlan)
        vlan ||= Array(@values[fn]).first
        set_value_from_list(fn, f, vlan, allowed_vlans)
      end
    end
  end

  def vm_name_preview(_options = {})
  end

  def update_field_visibility(options = {})
    if request_type == :clone_to_template
      show_dialog(:customize, :hide, "disabled")
    end

    update_field_display_values(options)

    update_field_display_notes_values

    update_field_read_only(options)
  end

  def update_field_read_only(options = {})
    read_only = get_value(@values[:sysprep_custom_spec]).blank? ? false : !(get_value(@values[:sysprep_spec_override]) == true)
    exclude_list = [:sysprep_spec_override, :sysprep_custom_spec, :sysprep_enabled, :sysprep_upload_file, :sysprep_upload_text]
    fields(:customize) { |fn, f, _dn, _d| f[:read_only] = read_only unless exclude_list.include?(fn) }
    return unless options[:read_only_fields]
    fields(:hardware) { |fn, f, _dn, _d| f[:read_only] = true if options[:read_only_fields].include?(fn) }
  end

  def allowed_hosts_obj(options = {})
    all_hosts = super
    filter_allowed_hosts(all_hosts)
  end

  def filter_allowed_hosts(all_hosts)
    filter_hosts_by_vlan_name(all_hosts)
  end

  def filter_hosts_by_vlan_name(all_hosts)
    vlan_name = get_value(@values[:vlan])
    return all_hosts unless vlan_name

    _log.info("Filtering hosts with the following network: <#{vlan_name}>")
    all_hosts.reject { |h| !h.lans.pluck(:name).include?(vlan_name) }
  end

  #
  # Methods for populating lists of allowed values for a field
  # => Input  - A hash containing options specific to the called method
  # => Output - A hash with the format: <value> => <value display name>
  # => New methods can be added as as needed
  #
  def allowed_cat_entries(options)
    rails_logger('allowed_cat_entries', 0)
    @values["#{options[:prov_field_name]}_category".to_sym] = options[:category]
    cat = Classification.find_by_name(options[:category].to_s)
    result = cat ? cat.entries.each_with_object({}) { |e, h| h[e.name] = e.description } : {}
    rails_logger('allowed_cat_entries', 1)
    result
  end

  def allowed_vlans(options = {})
    @allowed_vlan_cache ||= available_vlans_and_hosts(options)[0]
    filter_by_tags(@allowed_vlan_cache, options)
  end

  def available_vlans_and_hosts(options = {})
    @vlan_options ||= options
    vlans = {}
    src = get_source_and_targets
    return vlans if src.blank?

    hosts = get_selected_hosts(src)
    unless @vlan_options[:vlans] == false
      rails_logger('allowed_vlans', 0)
      # TODO: Use Active Record to preload this data?
      MiqPreloader.preload(hosts, :lans => :switches)
      load_allowed_vlans(hosts, vlans)
      rails_logger('allowed_vlans', 1)
    end

    return vlans, hosts
  end

  def load_allowed_vlans(hosts, vlans)
    load_hosts_vlans(hosts, vlans)
  end

  def load_hosts_vlans(hosts, vlans)
    hosts.each do |h|
      h.lans.each { |l| vlans[l.name] = l.name unless l.switch.shared? }
    end
  end

  def filter_by_tags(target, options)
    opt_filters = options[:tag_filters]
    return target if opt_filters.blank?

    filters = []
    selected_cats = selected_tags_by_cat_and_name
    if opt_filters.kind_of?(Hash)
      opt_filters.each do |cat, f|
        selected_tag = selected_cats[cat.to_s]
        if selected_tag.nil?
          # If no tags are selected check for a filter with a tag of nil to process
          f.each { |fd| filters << fd if fd[:tag].nil? }
        else
          f.each do |fd|
            selected_tag.each do |st|
              filters << fd if fd[:tag] =~ st
            end
          end
        end
      end
    end

    result = target.dup
    filters.each do |f|
      result.delete_if do |key, name|
        test_str = f[:key] == :key ? key : name
        f[:modifier] == "!" ? test_str =~ f[:filter] : test_str !~ f[:filter]
      end
    end

    result
  end

  def selected_tags_by_cat_and_name
    tag_ids = (@values[:vm_tags].to_miq_a + @values[:pre_dialog_vm_tags].to_miq_a).uniq
    return {} if tag_ids.blank?

    # Collect the filter tags by category
    allowed_tags_and_pre_tags.each_with_object({}) do |cat, hsh|
      children = cat[:children].each_with_object({}) { |value, result| result[value.first] = value.last }
      selected_ids = (children.keys & tag_ids)
      hsh[cat[:name]] = selected_ids.collect { |t_id| children[t_id][:name] } unless selected_ids.blank?
    end
  end

  def tag_symbol
    :vm_tags
  end

  def allowed_templates(options = {})
    # Return pre-selected VM if we are called for cloning
    if [:clone_to_vm, :clone_to_template].include?(request_type)
      vm_or_template = VmOrTemplate.find_by(:id => get_value(@values[:src_vm_id]))
      return [create_hash_struct_from_vm_or_template(vm_or_template, options)].compact
    end

    filter_id = get_value(@values[:vm_filter]).to_i
    if filter_id == @allowed_templates_filter && (options[:tag_filters].blank? || (@values[:vm_tags] == @allowed_templates_tag_filters))
      return @allowed_templates_cache
    end

    rails_logger('allowed_templates', 0)
    vms = VmOrTemplate.in_my_region.all
    condition = allowed_template_condition

    unless options[:tag_filters].blank?
      tag_filters = options[:tag_filters].collect(&:to_s)
      selected_tags = (@values[:vm_tags].to_miq_a + @values[:pre_dialog_vm_tags].to_miq_a).uniq
      tag_conditions = []

      # Collect the filter tags by category
      unless selected_tags.blank?
        allowed_tags_and_pre_tags.each do |cat|
          if tag_filters.include?(cat[:name])
            children_keys = cat[:children].each_with_object({}) { |t, h| h[t.first] = t.last }
            conditions = (children_keys.keys & selected_tags).collect { |t_id| "#{cat[:name]}/#{children_keys[t_id][:name]}" }
          end
          tag_conditions << conditions unless conditions.blank?
        end
      end

      unless tag_conditions.blank?
        _log.info("Filtering VM templates with the following tag_filters: <#{tag_conditions.inspect}>")
        vms = MiqTemplate.in_my_region.where(condition).find_tags_by_grouping(tag_conditions, :ns => "/managed")
      end
    end

    allowed_templates_list = source_vm_rbac_filter(vms, condition).to_a
    @allowed_templates_filter = filter_id
    @allowed_templates_tag_filters = @values[:vm_tags]
    rails_logger('allowed_templates', 1)
    if allowed_templates_list.blank?
      _log.warn("Allowed Templates is returning an empty list")
    else
      _log.warn("Allowed Templates is returning <#{allowed_templates_list.length}> template(s)")
      allowed_templates_list.each do |vm|
        _log.debug("Allowed Template <#{vm.id}:#{vm.name}>  GUID: <#{vm.guid}>  UID_EMS: <#{vm.uid_ems}>")
      end
    end

    MiqPreloader.preload(allowed_templates_list, [:snapshots, :operating_system, :ext_management_system, {:hardware => :disks}])
    @allowed_templates_cache = allowed_templates_list.collect do |template|
      create_hash_struct_from_vm_or_template(template, options)
    end

    @allowed_templates_cache
  end

  def allowed_template_condition
    return ["vms.template = ? AND vms.ems_id IS NOT NULL", true] unless self.class.respond_to?(:provider_model)

    ["vms.template = ? AND vms.ems_id in (?)", true, self.class.provider_model.pluck(:id)]
  end

  def source_vm_rbac_filter(vms, condition = nil)
    MiqSearch.filtered(get_value(@values[:vm_filter]).to_i, VmOrTemplate, vms,
                       :user => @requester, :conditions => condition)
  end

  def allowed_provision_types(_options = {})
    {}
  end

  def allowed_snapshots(_options = {})
    result = {}
    return result if (vm = get_source_vm).blank?
    vm.snapshots.each { |ss| result[ss.id.to_s] = ss.current? ? "#{ss.name} (Active)" : ss.name }
    result["__CURRENT__"] = _(" Use the snapshot that is active at time of provisioning") unless result.blank?
    result
  end

  def allowed_tags(options = {})
    return {} if (source = load_ar_obj(get_source_vm)).blank?
    super(options.merge(:region_number => source.region_number))
  end

  def allowed_pxe_servers(_options = {})
    return {} if (source = load_ar_obj(get_source_vm)).blank?
    PxeServer.in_region(source.region_number).each_with_object({}) { |p, h| h[p.id] = p.name }
  end

  def get_source_vm
    get_source_and_targets[:vm]
  end

  def get_source_and_targets(refresh = false)
    return @target_resource if @target_resource && refresh == false

    vm_id = get_value(@values[:src_vm_id])
    rails_logger('get_source_and_targets', 0)
    svm = VmOrTemplate.find_by(:id => vm_id)

    if svm.nil?
      @vm_snapshot_count = 0
      return @target_resource = {}
    end

    @vm_snapshot_count = svm.v_total_snapshots
    result = {}
    result[:vm] = ci_to_hash_struct(svm)
    result[:ems] = ci_to_hash_struct(svm.ext_management_system)

    result
  end


  def resources_for_ui
    auto_placement_enabled? ? {} : super
  end

  def allowed_customization_specs(_options = {})
    src = get_source_and_targets
    return [] if src.blank? || src[:ems].nil?

    customization_type = get_value(@values[:sysprep_enabled])
    return [] if customization_type.blank? || customization_type == 'disabled'

    @customization_specs ||= {}
    ems_id = src[:ems].id
    unless @customization_specs.key?(ems_id)
      rails_logger('allowed_customization_specs', 0)
      @customization_specs[ems_id] = ci_to_hash_struct(load_ar_obj(src[:ems]).customization_specs)
      rails_logger('allowed_customization_specs', 1)
    end

    result = @customization_specs[ems_id].dup
    source_platform = src[:vm].platform.capitalize
    result.delete_if { |cs| source_platform != cs.typ }
    result.delete_if(&:is_sysprep_spec?) if customization_type == 'file'
    result.delete_if { |cs| !cs.is_sysprep_spec? } if customization_type == 'fields'
    result
  end

  def allowed_customization(_options = {})
    src = get_source_and_targets
    return {} if src.blank?
    return {"fields" => "Specification"} if @values[:forced_sysprep_enabled] == 'fields'

    result = {"disabled" => "<None>"}

    case src[:vm].platform
    when 'windows' then result.merge!("fields" => "Specification", "file"  => "Sysprep Answer File")
    when 'linux'   then result["fields"] = "Specification"
    end

    result
  end

  def allowed_number_of_vms(options = {})
    options = {:min => 1, :max => 50}.merge(options)
    min, max = options[:min].to_i, options[:max].to_i
    min = 1 if min < 1
    max = min if max < 1
    (min..max).each_with_object({}) { |i, h| h[i] = i.to_s }
  end

  def load_test_ous_data
    return @ldap_ous unless @ldap_ous.nil?
    ous = YAML.load_file("ous.yaml")
    @ldap_ous = {}
    ous.each { |ou| @ldap_ous[ou[0].dup] = ou[1].dup }
    @ldap_ous
  end

  def allowed_organizational_units(options = {})
    {}
  end

  def allowed_ous_tree(_options = {})
    hous = {}
    ous = allowed_organizational_units
    return ous if ous.blank?

    dc_path = ous.keys.first.split(',').collect { |i| i.split("DC=")[1] }.compact.join(".")
    ous.each { |ou| create_ou_tree(ou, hous[dc_path] ||= {}, ou[0].split(',')) }

    # Re-adjust path for remove levels without OUs.
    root, path = find_first_ou(hous[dc_path])
    unless path.nil?
      root_name = hous.keys[0]
      new_name = "#{root_name}  (#{path})"
      hous[new_name] = root
      hous.delete(root_name)
    end

    hous
  end

  def find_first_ou(hous, path = nil)
    if hous.key?(:ou)
      find_first_ou(hous[key], path)
    else
      key = hous.keys.first
      if hous[key].key?(:ou)
        return hous, path
      else
        path = path.nil? ? key : "#{path} / #{key}"
        find_first_ou(hous[key], path)
      end
    end
  end

  def build_ou_path_name(ou)
    path_name = ''
    paths = ou[0].split(',').reverse
    paths.each do |path|
      parts = path.split('=')
      next if parts.first == 'DC'
      path_name = path_name.blank? ? parts.last : File.join(path_name, parts.last)
      ou[1].replace(path_name)
    end
  end

  def create_ou_tree(ou, h, path)
    idx = path.pop
    type, pathname = idx.split('=')
    if type == "DC"
      create_ou_tree(ou, h, path)
    else
      if path.blank?
        entry = (h[pathname] ||= {})
        entry[:path] = ou[0]
        entry[:ou] = ou
      else
        create_ou_tree(ou, h[pathname] ||= {}, path)
      end
    end
  end

  def allowed_domains(options = {})
    @domains ||= begin
      domains = {}
      if @values[:forced_sysprep_domain_name].blank?
        Host.all.each do |host|
          domain = host.domain.to_s.downcase
          next if domain.blank? || domains.key?(domain)
          # Filter by host platform or is proxy is active
          next unless options[:platform].nil? || options[:platform].include?(host.platform)
          next unless options[:active_proxy].nil? || host.is_proxy_active? == options[:active_proxy]
          domains[domain] = domain
        end
      else
        @values[:forced_sysprep_domain_name].to_miq_a.each { |d| domains[d] = d }
      end
      domains
    end
  end

  def update_custom_spec
    vm = get_source_vm
    return if vm.nil?
    if @customize_option.nil?
      @current_spec = get_value(@values[:sysprep_custom_spec])
      @customize_option = get_value(@values[:sysprep_enabled])
      @custom_spec_override = get_value(@values[:sysprep_spec_override])
    end

    if @customization_specs.nil?
      @customize_option = get_value(@values[:sysprep_enabled])
      return
    end

    # Force selected customization spec to <None> if the Customization option changes
    selected_spec = get_value(@values[:sysprep_custom_spec])
    current_customize_option = get_value(@values[:sysprep_enabled])
    current_spec_override = get_value(@values[:sysprep_spec_override])
    if current_customize_option != @customize_option
      @customize_option = current_customize_option
      selected_spec = nil
      @values[:sysprep_custom_spec] = [nil, nil]
      @values[:sysprep_spec_override] = [false, 0]
    end

    return if @current_spec == selected_spec && @custom_spec_override == current_spec_override

    _log.info("Custom spec changed from [#{@current_spec}] to [#{selected_spec}].  Customize option:[#{@customize_option}]")

    if selected_spec
      src = get_source_and_targets
      ems_id = src[:ems].id

      cs_data = @customization_specs[ems_id].detect { |s| s.name == selected_spec }
      if cs_data.nil?
        selected_spec_int = selected_spec.to_i
        cs_data = @customization_specs[ems_id].detect { |s| s.id == selected_spec_int }
      end

      if cs_data
        cs_data = load_ar_obj(cs_data)

        if @customize_option == 'file'
          @values[:sysprep_upload_text] = cs_data[:spec].fetch_path('identity', 'value')
        end

        # Call platform specific method
        send("update_fields_from_spec_#{cs_data[:typ].downcase}", cs_data)

        # Call generic networking method
        update_fields_from_spec_networking(cs_data)
      end
    else
      @values[:sysprep_upload_text] = nil if @customize_option == 'file'
    end

    @current_spec = selected_spec
    @custom_spec_override = current_spec_override
  end

  def update_fields_from_spec_windows(cs_data)
    spec_hash = {}
    spec      = cs_data[:spec]
    dialog    = @dialogs.fetch_path(:dialogs, :customize)

    collect_customization_spec_settings(spec, spec_hash, %w(identity guiUnattended),
                                        [:sysprep_timezone, 'timeZone', :sysprep_auto_logon, 'autoLogon', :sysprep_auto_logon_count, 'autoLogonCount'])

    collect_customization_spec_settings(spec, spec_hash, %w(identity identification),
                                        [:sysprep_domain_name, 'joinDomain', :sysprep_domain_admin, 'domainAdmin', :sysprep_workgroup_name, 'joinWorkgroup'])

    # PATH:[identity][userData][computerName][name] (VimString) = "VI25Test"
    collect_customization_spec_settings(spec, spec_hash, %w(identity userData),
                                        [:sysprep_organization, 'orgName', :sysprep_full_name, 'fullName', :sysprep_product_id, 'productId'])

    collect_customization_spec_settings(spec, spec_hash, %w(identity licenseFilePrintData),
                                        [:sysprep_server_license_mode, 'autoMode', :sysprep_per_server_max_connections, 'autoUsers'])

    collect_customization_spec_settings(spec, spec_hash, ['options'],
                                        [:sysprep_change_sid, 'changeSID', :sysprep_delete_accounts, 'deleteAccounts'])

    spec_hash[:sysprep_identification] = spec_hash[:sysprep_domain_name].blank? ? 'workgroup' : 'domain'

    spec_hash.each { |k, v| set_customization_field_from_spec(v, k, dialog) }
  end

  def update_fields_from_spec_linux(cs_data)
    spec_hash = {}
    spec = cs_data[:spec]
    dialog = @dialogs.fetch_path(:dialogs, :customize)

    collect_customization_spec_settings(spec, spec_hash, ['identity'],
                                        [:linux_domain_name, 'domain', :linux_host_name, 'hostName'])

    spec_hash.each { |k, v| set_customization_field_from_spec(v, k, dialog) }
  end

  def update_fields_from_spec_networking(cs_data)
    spec_hash = {}
    spec      = cs_data[:spec]
    dialog    = @dialogs.fetch_path(:dialogs, :customize)

    first_adapter = spec['nicSettingMap'].to_miq_a.first
    if first_adapter.kind_of?(Hash)
      adapter = first_adapter['adapter']
      spec_hash[:dns_servers]  = adapter['dnsServerList'].to_miq_a.join(', ')
      spec_hash[:gateway]      = adapter['gateway'].to_miq_a.join(', ')
      spec_hash[:subnet_mask]  = adapter['subnetMask'].to_s
      spec_hash[:ip_addr]      = adapter.fetch_path('ip', 'ipAddress').to_s
      # Combine the WINS server fields into 1 comma separated field list
      spec_hash[:wins_servers] = [adapter['primaryWINS'], adapter['secondaryWINS']].collect { |s| s unless s.blank? }.compact.join(', ')
    end

    # In Linux, DNS server settings are global, not per adapter
    spec_hash[:dns_servers]  = spec.fetch_path('globalIPSettings', 'dnsServerList').to_miq_a.join(', ') if spec_hash[:dns_servers].blank?
    spec_hash[:dns_suffixes] = spec.fetch_path('globalIPSettings', 'dnsSuffixList').to_miq_a.join(', ')

    spec_hash[:addr_mode] = spec_hash[:ip_addr].blank? ? 'dhcp' : 'static'

    spec_hash.each { |k, v| set_customization_field_from_spec(v, k, dialog) }
  end

  def collect_customization_spec_settings(spec, spec_hash, spec_path, fields)
    return unless (section = spec.fetch_path(spec_path))
    fields.each_slice(2) { |dlg_field, prop| spec_hash[dlg_field] = section[prop] }
  end

  def set_customization_field_from_spec(data_value, dlg_field, dialog)
    field_hash  = dialog[:fields][dlg_field]
    data_type   = field_hash[:data_type]
    cust_method = "custom_#{dlg_field}"

    if self.respond_to?(cust_method)
      send(cust_method, field_hash, data_value)
    else
      value = case data_type
              when :boolean then data_value == "true"
              when :integer then data_value.to_i_with_method
              when :string  then data_value.to_s
              else               data_value
              end

      if field_hash.key?(:values)
        set_value_from_list(dlg_field, field_hash, value)
      else
        @values[dlg_field] = value
      end
    end
  end

  def target_type
    request_type == :clone_to_template ? 'template' : 'vm'
  end

  def source_type
    svm = get_source_vm
    if svm.nil?
      request_type == :template ? 'template' : 'unknown'
    else
      svm.template? ? 'template' : 'vm'
    end
  end

  def self.from_ws(*args)
    version = args.first.to_f
    return from_ws_ver_1_0(*args) if version == 1.0

    # Move optional arguments into the MiqHashStruct object
    prov_options = MiqHashStruct.new(
      :values                => args[6],
      :ems_custom_attributes => args[7],
      :miq_custom_attributes => args[8],
    )
    prov_args = args[0, 6]
    prov_args << prov_options
    from_ws_ver_1_x(*prov_args)
  end

  def self.from_ws_ver_1_0(version, user, src_name, target_name, auto_approve, tags, additional_values)
    _log.info("Web-service provisioning starting with interface version <#{version}> for user <#{user.userid}>")
    values = {}
    p = new(values, user, :use_pre_dialog => false)
    src_name_down = src_name.downcase
    src = p.allowed_templates.detect { |v| v.name.downcase == src_name_down }
    raise _("Source template [%{name}] was not found") % {:name => src_name} if src.nil?
    p = class_for_source(src.id).new(values, user, :use_pre_dialog => false)

    # Populate required fields
    p.init_from_dialog(values)
    values[:src_vm_id] = [src.id, src.name]
    p.refresh_field_values(values)
    values[:vm_name]          = target_name
    values[:placement_auto]   = [true, 1]
    values[:owner_first_name] = user.userid
    values[:owner_email]      = user.userid
    values[:owner_last_name]  = user.userid

    # Tags are passed as category|value|cat2|...  Example: cc|001|environment|test
    values[:vm_tags] = p.ws_tags(tags, :parse_ws_string_v1)
    values[:ws_values] = p.ws_values(additional_values, :parse_ws_string_v1)

    if p.validate(values) == false
      errors = []
      p.fields { |_fn, f, _dn, _d| errors << f[:error] unless f[:error].nil? }
      raise _("Provision failed for the following reasons:\n%{errors}") % {:errors => errors.join("\n")}
    end

    p.make_request(nil, values, nil, auto_approve)
  end

  def ws_template_fields(values, fields, ws_values)
    data = parse_ws_string(fields)
    ws_values = parse_ws_string(ws_values)
    placement_cluster_name = ws_values[:cluster]
    unless placement_cluster_name.blank?
      data[:placement_cluster_name] = placement_cluster_name.to_s.downcase
      _log.info("placement_cluster_name:<#{data[:placement_cluster_name].inspect}>")
      data[:data_centers] = EmsCluster.where("lower(name) = ?", data[:placement_cluster_name]).collect(&:v_parent_datacenter)
    end
    _log.info("data:<#{data.inspect}>")

    src_name =     data[:name].blank? ? nil : data[:name].downcase
    src_guid =     data[:guid].blank? ? nil : data[:guid].downcase
    ems_guid =     data[:ems_guid].blank? ? nil : data[:ems_guid].downcase
    data_centers = data[:data_centers]

    _log.info("VM Passed: <#{src_name}> <#{src_guid}> <#{ems_guid}> Datacenters:<#{data_centers.inspect}>")
    if [:clone_to_vm, :clone_to_template].include?(request_type)
      src = ws_find_template_or_vm(values, src_name, src_guid, ems_guid)
    else
      srcs = allowed_templates(:include_datacenter => true).find_all do |v|
        _log.info("VM Detected: <#{v.name.downcase}> <#{v.guid}> <#{v.uid_ems}> Datacenter:<#{v.datacenter_name}>")
        (src_name.nil? || src_name == v.name.downcase) && (src_guid.nil? || src_guid == v.guid) && (ems_guid.nil? || ems_guid == v.uid_ems) && (data_centers.nil? || data_centers.include?(v.datacenter_name))
      end
      if srcs.length > 1
        raise _("Multiple source template were found from input data:<%{data}>") % {:data => data.inspect}
      end
      src = srcs.first
    end
    if src.nil?
      raise _("No source template was found from input data:<%{data}>") % {:data => data.inspect}
    end
    _log.info("VM Found: <#{src.name}> <#{src.guid}> <#{src.uid_ems}>  Datacenter:<#{src.datacenter_name}>")
    src
  end

  def ws_find_template_or_vm(_values, src_name, src_guid, ems_guid)
    scope = VmOrTemplate
    scope = scope.where(:guid => src_guid) unless src_guid.blank?
    scope = scope.where(:uid_ems => ems_guid) unless ems_guid.blank?
    scope = scope.where(VmOrTemplate.arel_attribute("name").lower.eq(src_name)) unless src_name.blank?

    rbac_object = source_vm_rbac_filter(scope).first
    create_hash_struct_from_vm_or_template(rbac_object, :include_datacenter => true) if rbac_object
  end

  def ws_vm_fields(values, fields)
    data = parse_ws_string(fields)
    _log.info("data:<#{data.inspect}>")
    ws_service_fields(values, fields, data)
    ws_hardware_fields(values, fields, data)
    ws_network_fields(values, fields, data)
    ws_customize_fields(values, fields, data)
    ws_schedule_fields(values, fields, data)
    ws_environment_fields(values, data)

    data.each { |k, v| _log.warn("Unprocessed key <#{k}> with value <#{v.inspect}>") }
  end

  def ws_environment_fields(values, data)
    # do not parse environment data unless :placement_auto is false
    return unless data[:placement_auto].to_s == "false"

    values[:placement_auto] = [false, 0]
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :environment)).nil?

    data.keys.each { |key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_fields.key?(key) }
  end

  def ws_service_fields(values, _fields, data)
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :service)).nil?

    # Process PXE settings by setting the server first then image, windows image and custom template
    dlg_field = :pxe_server_id
    if dlg_fields.key?(dlg_field) && (data.key?(dlg_field) || data.key?(:pxe_server))
      set_ws_field_value_by_id_or_name(values, dlg_field, data, dialog_name, dlg_fields)

      dlg_field = :pxe_image_id
      get_field(dlg_field, dialog_name)
      set_ws_field_value_by_id_or_name(values, dlg_field, data, dialog_name, dlg_fields, nil, "PxeImage")

      # Windows images are also stored with the pxe_image values
      set_ws_field_value_by_id_or_name(values, dlg_field, data, dialog_name, dlg_fields, :windows_image_id, "WindowsImage")
    end

    data.keys.each { |key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_fields.key?(key) }
  end

  def ws_hardware_fields(values, _fields, data)
    ws_hardware_scsi_controller_fields(values, data)
    ws_hardware_disk_fields(values, data)
    ws_hardware_network_fields(values, data)
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :hardware)).nil?
    data.keys.each { |key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_fields.key?(key) }
  end

  def ws_hardware_network_fields(values, data)
    parse_ws_hardware_fields(:networks, /^network(\d{1,2})$/, values, data) { |n, v, _i| n[:network] = v }

    # Check and remove invalid networks specifications
    values[:networks].delete_if do |d|
      result = d[:network].blank?
      _log.warn("Skipping network due to blank name: <#{d.inspect}>")  if result == true
      result
    end unless values[:networks].blank?
  end

  def ws_hardware_scsi_controller_fields(values, data)
    parse_ws_hardware_fields(:ctrl_scsi, /^ctrlscsi(\d{1,2})$/, values, data) do |ctrl, value, idx|
      ctrl.merge!(:busnumber => idx, :devicetype => value)
    end
  end

  def ws_hardware_disk_fields(values, data)
    parse_ws_hardware_fields(:disk_scsi, /^diskscsi(\d{1,2})$/, values, data) do |disk, value, _idx|
      d_parms = value.split(':')
      disk[:bus]      = d_parms[0] || '*'
      disk[:pos]      = d_parms[1] || '*'
      disk[:sizeInMB] = d_parms[2]
    end

    # Check and remove invalid disk specifications
    values[:disk_scsi].delete_if do |d|
      result = d[:sizeInMB].to_i == 0
      _log.warn("Skipping disk due to invalid size: <#{d.inspect}>") if result == true
      result
    end unless values[:disk_scsi].blank?
  end

  def parse_ws_hardware_fields(hw_key, regex_filter, values, data)
    data.keys.each do |k|
      key_name = k.to_s.split('.').first
      next unless key_name =~ regex_filter
      item_id = Regexp.last_match(1).to_i
      v = data.delete(k)
      _log.info("processing key <hardware:#{k}(#{v.class})> with value <#{v.inspect}>")

      values[hw_key] ||= []
      item = values[hw_key][item_id] ||= {}

      key_names = k.to_s.split('.')[1..-1]
      if key_names.length == 0
        # Caller needs to parse the default value
        yield(item, v, item_id)
      elsif key_names.length == 1
        item[key_names[0].to_sym] = v
      elsif key_names.length > 1
        item.store_path(*(key_names.collect(&:to_sym) << v))
      end
    end
    values[hw_key].compact! unless values[hw_key].nil?
  end

  def ws_network_fields(values, _fields, data)
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :network)).nil?
    data.keys.each { |key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_fields.key?(key) }
  end

  def ws_customize_fields(values, _fields, data)
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :customize)).nil?

    key = :customization_template_id
    if dlg_fields.key?(key) && (data.key?(key) || data.key?(:customization_template))
      get_field(key, dialog_name)
      set_ws_field_value_by_id_or_name(values, key, data, dialog_name, dlg_fields)
    end

    data.keys.each { |k| set_ws_field_value(values, k, data, dialog_name, dlg_fields) if dlg_fields.key?(k) }
  end

  def self.from_ws_ver_1_x(version, user, template_fields, vm_fields, requester, tags, options)
    options = MiqHashStruct.new if options.nil?
    _log.warn("Web-service provisioning starting with interface version <#{version}> by requester <#{user.userid}>")

    init_options = {:use_pre_dialog => false, :request_type => request_type(parse_ws_string(template_fields)[:request_type]), :initial_pass => true}
    data = parse_ws_string(requester)

    user = update_requester_from_parameters(data, user)

    p = new(values = {}, user, init_options)
    src = p.ws_template_fields(values, template_fields, options.values)
    raise _("Source template [%{name}] was not found") % {:name => src_name} if src.nil?
    # Allow new workflow class to determine dialog name instead of using the stored value from the first call.
    values.delete(:miq_request_dialog_name)
    values[:placement_auto] = [true, 1]
    values[:src_vm_id]      = [src.id, src.name]
    p = class_for_source(src.id).new(values, user, init_options)

    # Populate required fields
    p.init_from_dialog(values)
    p.refresh_field_values(values)

    p.ws_vm_fields(values, vm_fields)
    p.ws_requester_fields(values, requester)
    values[:vm_tags] = p.ws_tags(tags)    # Tags are passed as category=value|cat2=value2...  Example: cc=001|environment=test
    values[:ws_values] = p.ws_values(options.values)
    values[:ws_ems_custom_attributes] = p.ws_values(options.ems_custom_attributes, :parse_ws_string, :modify_key_name => false)
    values[:ws_miq_custom_attributes] = p.ws_values(options.miq_custom_attributes, :parse_ws_string, :modify_key_name => false)

    p.make_request(nil, values, nil, values[:auto_approve]).tap do |request|
      p.raise_validate_errors if request == false
    end
  rescue => err
    _log.error("<#{err}>")
    raise err
  end

  private

  def dialog_field_visibility_service
    @dialog_field_visibility_service ||= DialogFieldVisibilityService.new
  end

  def update_field_display_values(options = {})
    options_hash = setup_parameters_for_visibility_service(options)
    visibility_hash = dialog_field_visibility_service.determine_visibility(options_hash)

    fields do |field_name, field, _, _|
      dialog_field_visibility_service.set_visibility_for_field(visibility_hash, field_name, field)
    end
  end

  def update_field_display_notes_values
    field_note_visibility = Hash.new([])

    edit_or_hide = get_value(@values[:number_of_vms]).to_i > 1 ? :edit : :hide
    field_note_visibility[edit_or_hide] += [:ip_addr]

    edit_or_hide = @vm_snapshot_count.zero? ? :edit : :hide
    field_note_visibility[edit_or_hide] += [:linked_clone]

    field_note_visibility.each { |display_flag, field_names| show_fields(display_flag, field_names, :notes_display) }
  end

  def setup_parameters_for_visibility_service(options)
    vm = get_source_vm
    platform = options[:force_platform] || vm.try(:platform)

    number_of_vms = get_value(@values[:number_of_vms]).to_i

    customize_fields_list = []
    fields(:customize) do |field_name, _, _, _|
      customize_fields_list << field_name.to_sym
    end

    {
      :addr_mode                       => get_value(@values[:addr_mode]),
      :auto_placement_enabled          => auto_placement_enabled?,
      :customize_fields_list           => customize_fields_list,
      :linked_clone                    => get_value(@values[:linked_clone]),
      :number_of_vms                   => number_of_vms,
      :platform                        => platform,
      :provision_type                  => get_value(@values[:provision_type]),
      :request_type                    => request_type,
      :retirement                      => get_value(@values[:retirement]).to_i,
      :service_template_request        => get_value(@values[:service_template_request]),
      :snapshot_count                  => @vm_snapshot_count,
      :supports_customization_template => supports_customization_template?,
      :supports_iso                    => supports_iso?,
      :supports_pxe                    => supports_pxe?,
      :sysprep_auto_logon              => get_value(@values[:sysprep_auto_logon]),
      :sysprep_custom_spec             => get_value(@values[:sysprep_custom_spec]),
      :sysprep_enabled                 => get_value(@values[:sysprep_enabled])
    }
  end

  def create_hash_struct_from_vm_or_template(vm_or_template, options)
    data_hash = {:id                     => vm_or_template.id,
                 :name                   => vm_or_template.name,
                 :guid                   => vm_or_template.guid,
                 :uid_ems                => vm_or_template.uid_ems,
                 :platform               => vm_or_template.platform,
                 :logical_cpus           => vm_or_template.cpu_total_cores,
                 :mem_cpu                => vm_or_template.mem_cpu,
                 :allocated_disk_storage => vm_or_template.allocated_disk_storage,
                 :v_total_snapshots      => vm_or_template.v_total_snapshots,
                 :evm_object_class       => :Vm}
    data_hash[:cloud_tenant] = vm_or_template.cloud_tenant if vm_or_template.respond_to?(:cloud_tenant)
    hash_struct = MiqHashStruct.new(data_hash)
    hash_struct.operating_system = MiqHashStruct.new(
      :product_name => vm_or_template.operating_system.product_name
    ) if vm_or_template.operating_system
    hash_struct.ext_management_system = MiqHashStruct.new(
      :name => vm_or_template.ext_management_system.name
    ) if vm_or_template.ext_management_system
    if options[:include_datacenter] == true
      hash_struct.datacenter_name = vm_or_template.owning_blue_folder.try(:parent_datacenter).try(:name)
    end

    hash_struct
  end

  def exit_pre_dialog
    @running_pre_dialog              = false
    @values[:pre_dialog_vm_tags]     = @values[:vm_tags].dup
    @values[:forced_sysprep_enabled] = 'fields' if @values[:sysprep_enabled] == 'fields'

    if (sdn = @values[:sysprep_domain_name]).presence.kind_of?(String)
      @values[:sysprep_domain_name]        = [sdn, sdn]
      @values[:forced_sysprep_domain_name] = [sdn]
    end
  end

  def get_selected_hosts(src)
    # Add all the Lans for the available host(s)
    hosts = if auto_placement_enabled?
              all_provider_hosts(src)
            elsif src[:host_id]
              selected_host(src)
            else
              allowed_hosts.group_by(&:evm_object_class).flat_map do |type, objs|
                type.to_s.camelize.constantize.where(:id => objs.map(&:id)).to_a
              end
            end
    Rbac.filtered(hosts, :class => Host, :user => @requester)
  end

  def all_provider_hosts(src)
    load_ar_obj(src[:ems]).try(:hosts) || []
  end

  def selected_host(src)
    raise _("Unable to find Host with Id: [%{id}]") % {:id => src[:host_id]} if src[:host].nil?
    [load_ar_obj(src[:host])]
  end
end
