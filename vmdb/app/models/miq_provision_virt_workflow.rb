require 'active_support/deprecation'

class MiqProvisionVirtWorkflow < MiqProvisionWorkflow
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
        vm = VmOrTemplate.find_by_id(src_vm_id)
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

  def create_request(values, requester_id, auto_approve = false)
    if @running_pre_dialog == true
      continue_request(values, requester_id)
      password_helper(values, true)
      return nil
    else
      event_message = "VM Provision requested by [#{requester_id}] for VM:#{values[:src_vm_id].inspect}"
      super(values, requester_id, 'Vm', 'vm_provision_request_updated', event_message, auto_approve)
    end
  end

  def update_request(request, values, requester_id)
    event_message = "VM Provision request was successfully updated by [#{requester_id}] for VM:#{values[:src_vm_id].inspect}"
    super(request, values, requester_id, 'Vm', 'vm_migrate_request_updated', event_message)
  end

  def refresh_field_values(values, requester_id)
    log_header = "MIQ(#{self.class.name}#refresh_field_values)"

    begin
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
      $log.info "#{log_header} provision refresh completed in [#{Time.now - st}] seconds"
    rescue => err
      $log.error "#{log_header} [#{err}]"
      $log.error err.backtrace.join("\n")
      raise err
    ensure
      @allowed_vlan_cache = nil
    end
  end

  def custom_sysprep_timezone(field, data_value)
    set_value_from_list(:sysprep_timezone, field, "%03d" % data_value, @timezones)
    @values[:sysprep_timezone].reverse!
  end

  def custom_sysprep_domain_name(field, data_value)
    set_value_from_list(:sysprep_domain_name, field, data_value, nil, true)
  end

  def set_on_vm_id_changed
    src = get_source_and_targets
    vm, ems = load_ar_obj(src[:vm]), src[:ems]

    clear_field_values([:placement_host_name, :placement_ds_name, :placement_folder_name, :placement_cluster_name, :placement_rp_name, :linked_clone, :snapshot])

    if vm.nil?
      clear_field_values([:number_of_cpus, :number_of_sockets, :cores_per_socket, :vm_memory, :cpu_limit, :memory_limit, :cpu_reserve, :memory_reserve])
      vm_description = nil
      vlan = nil
      show_dialog(:customize, :show, "disabled")
    else
      raise "Source VM [#{vm.name}] does not belong to a #{ui_lookup(:table => "ext_management_systems")}" if vm.ext_management_system.nil?
      set_or_default_hardware_field_values(vm)

      # Record the nic/lan setting on the template for validation checks at provision time.
      @values[:src_vm_nics] = vm.hardware.nil? ? nil : vm.hardware.nics.collect(&:device_name).compact
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
        set_value_from_list(fn, f, vlan, allowed_vlans)
      end
    end
  end

  def vm_name_preview(_options = {})
  end

  def validate_vm_name(field, values, dlg, fld, value)
    validate_length(field, values, dlg, fld, value)
  end

  def validate_memory_reservation(_field, values, dlg, fld, _value)
    allocated = get_value(values[:vm_memory]).to_i
    reserved  = get_value(values[:memory_reserve]).to_i
    "#{required_description(dlg, fld)} Reservation is larger than VM Memory" if reserved > allocated
  end

  def validate_pxe_image_id(_field, _values, dlg, fld, _value)
    return nil unless supports_pxe?
    return nil unless get_pxe_image.nil?
    "#{required_description(dlg, fld)} is required"
  end

  def validate_pxe_server_id(_field, _values, dlg, fld, _value)
    return nil unless supports_pxe?
    return nil unless get_pxe_server.nil?
    "#{required_description(dlg, fld)} is required"
  end

  def validate_placement(field, values, dlg, fld, value)
    # check the :placement_auto flag, then make sure the field is not blank
    return nil unless value.blank?
    return nil if get_value(values[:placement_auto]) == true
    return nil unless get_value(values[field]).blank?
    "#{required_description(dlg, fld)} is required"
  end

  def validate_sysprep_upload(field, values, dlg, fld, value)
    return nil unless value.blank?
    return nil unless get_value(values[:sysprep_enabled]) == 'file'
    return nil unless get_value(values[field]).blank?
    "#{required_description(dlg, fld)} is required"
  end

  def validate_sysprep_field(field, values, dlg, fld, value)
    return nil unless value.blank?
    return nil unless get_value(values[:sysprep_enabled]) == 'fields'
    return nil unless get_value(values[field]).blank?
    "#{required_description(dlg, fld)} is required"
  end

  def default_require_sysprep_enabled(_field, _values, dlg, fld, value)
    "#{required_description(dlg, fld)} is required" if value.blank? || value == "disabled"
  end

  def default_require_sysprep_custom_spec(_field, _values, dlg, fld, value)
    "#{required_description(dlg, fld)} is required" if value.blank? || value == "__VC__NONE__"
  end

  def update_field_visibility(options = {})
    # Determine the visibility of fields based on current values and collect the fields
    # together so we can update the dialog in one pass

    number_of_vms = get_value(@values[:number_of_vms]).to_i

    # Show/Hide Fields
    f = Hash.new { |h, k| h[k] = Array.new }

    if get_value(@values[:service_template_request])
      f[:hide] = [:number_of_vms, :vm_description, :schedule_type, :schedule_time]
    end

    auto_placement = show_flag = auto_placement_enabled? ? :hide : :edit
    f[show_flag] += [:placement_host_name, :placement_ds_name, :host_filter, :ds_filter, :cluster_filter, :placement_cluster_name, :rp_filter, :placement_rp_name]

    show_flag = get_value(@values[:sysprep_enabled]).in?('fields', 'file') || self.supports_pxe? || self.supports_iso? ? :edit : :hide
    f[show_flag] += [:addr_mode]

    # If we are hiding the network fields always hide.  If available then the show_flag depends on the addr_mode
    if show_flag == :edit
      f[show_flag] += [:dns_suffixes, :dns_servers]
      show_flag = (get_value(@values[:addr_mode]) == 'static') || self.supports_pxe? || self.supports_iso? ? :edit : :hide
      f[show_flag] += [:ip_addr, :subnet_mask, :gateway]
    else
      # Hide all networking fields if we are not customizing
      f[show_flag] += [:ip_addr, :subnet_mask, :gateway, :dns_servers, :dns_suffixes]
    end

    show_flag = get_value(@values[:sysprep_auto_logon]) == false ? :hide : :edit
    f[show_flag] += [:sysprep_auto_logon_count]

    show_flag = number_of_vms > 1 ? :hide : :edit
    f[show_flag] += [:sysprep_computer_name]

    show_flag = get_value(@values[:retirement]).to_i > 0 ? :edit : :hide
    f[show_flag] += [:retirement_warn]
    vm = get_source_vm
    platform = options[:force_platform] || vm.try(:platform)
    show_customize_fields(f, platform)

    show_flag = number_of_vms > 1 ? :hide : :edit
    if platform == 'linux'
      f[show_flag] += [:linux_host_name]
      f[:hide] += [:sysprep_computer_name]
    else
      f[show_flag] += [:sysprep_computer_name]
      f[:hide] += [:linux_host_name]
    end

    show_flag = get_value(@values[:sysprep_custom_spec]).blank? ? :hide : :edit
    f[show_flag] += [:sysprep_spec_override]

    # Hide VM filter if we are using a pre-selected VM
    if [:clone_to_vm, :clone_to_template].include?(request_type)
      f[:hide] += [:vm_filter]
      if request_type == :clone_to_template
        show_dialog(:customize, :hide, "disabled")
        f[:hide] += [:vm_auto_start]
      end
    end

    update_field_visibility_linked_clone(options, f)

    # Update field :display value
    f.each { |k, v| show_fields(k, v) }

    # Show/Hide Notes
    f = Hash.new { |h, k| h[k] = Array.new }

    show_flag = number_of_vms > 1 ? :edit : :hide
    f[show_flag] += [:ip_addr]

    show_flag = @vm_snapshot_count.zero? ? :edit : :hide
    f[show_flag] += [:linked_clone]

    # Update field :notes_display value
    f.each { |k, v| show_fields(k, v, :notes_display) }

    # need to set required to false for the fields that are not being shown on screen,
    # based upon ISO/PXE choices in provision tpe pulldown
    update_field_required

    update_field_read_only(options)
  end

  def update_field_visibility_linked_clone(_options = {}, f)
    if get_value(@values[:provision_type]).to_s == 'vmware'
      show_flag = @vm_snapshot_count.zero? ? :show : :edit
      f[show_flag] += [:linked_clone]

      show_flag = get_value(@values[:linked_clone]) == true ? :edit : :hide
      f[show_flag] += [:snapshot]
    else
      f[:hide] += [:linked_clone, :snapshot]
    end
  end

  def update_field_required
    fields(:service) do |fn, f, _dn, _d|
      f[:required] =  supports_pxe? ? f[:required] : false if [:pxe_image_id, :pxe_server_id].include?(fn)
      f[:required] =  supports_iso? ? f[:required] : false if [:iso_image_id].include?(fn)
    end
  end

  def show_customize_fields_pxe(fields)
    pxe_customization_fields = [
      :root_password,
      :addr_mode,
      :hostname,
      :ip_addr,
      :subnet_mask,
      :gateway,
      :dns_servers,
      :dns_suffixes,
      :customization_template_id,
      :customization_template_script,
    ]

    pxe_customization_fields.each do |f|
      fields[:edit].push(f) unless fields[:edit].include?(f)
      fields[:hide].delete(f)
    end
  end

  def show_customize_fields(fields, platform)
    # ISO and cloud-init prov. needs to show same fields on customize tab as Pxe prov.
    return show_customize_fields_pxe(fields) if self.supports_customization_template?

    exclude_list = [:sysprep_spec_override, :sysprep_custom_spec, :sysprep_enabled, :sysprep_upload_file, :sysprep_upload_text,
                    :linux_host_name, :sysprep_computer_name, :ip_addr, :subnet_mask, :gateway, :dns_servers, :dns_suffixes]
    linux_fields = [:linux_domain_name]
    show_options = [:edit, :hide]
    show_options.reverse! if platform == 'linux'
    self.fields(:customize) do |fn, _f, _dn, _d|
      next if exclude_list.include?(fn)
      linux_fields.include?(fn) ? fields[show_options[1]] += [fn] : fields[show_options[0]] += [fn]
    end
  end

  def update_field_read_only(options = {})
    read_only = get_value(@values[:sysprep_custom_spec]).blank? ? false : !(get_value(@values[:sysprep_spec_override]) == true)
    exclude_list = [:sysprep_spec_override, :sysprep_custom_spec, :sysprep_enabled, :sysprep_upload_file, :sysprep_upload_text]
    fields(:customize) { |fn, f, _dn, _d| f[:read_only] = read_only unless exclude_list.include?(fn) }
    return unless options[:read_only_fields]
    fields(:hardware) { |fn, f, _dn, _d| f[:read_only] = true if options[:read_only_fields].include?(fn) }
  end

  def set_default_values
    super
    set_default_filters
  end

  def set_default_filters
    [[:requester, :vm_filter, :Vm], [:environment, :host_filter, :Host], [:environment, :ds_filter, :Storage], [:environment, :cluster_filter, :EmsCluster]].each do |dialog, field, model|
      filter = @dialogs.fetch_path(:dialogs, dialog, :fields, field)
      unless filter.nil?
        current_filter = get_value(@values[field])
        filter[:default] = current_filter.nil? ? @requester.settings.fetch_path(:default_search, model) : current_filter
      end
    end
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
    if @allowed_vlan_cache.nil?
      @vlan_options ||= options
      vlans = {}
      src = get_source_and_targets
      return vlans if src.blank?

      hosts = nil
      unless @vlan_options[:vlans] == false
        rails_logger('allowed_vlans', 0)
        hosts = get_selected_hosts(src)
        # TODO: Use Active Record to preload this data?
        MiqPreloader.preload(hosts, :switches => :lans)
        hosts.each { |h| h.lans.each { |l| vlans[l.name] = l.name } }

        # Remove certain networks
        vlans.delete_if { |_k, v| v.in?('Service Console', 'VMkernel') }
        rails_logger('allowed_vlans', 1)
      end

      unless @vlan_options[:dvs] == false
        rails_logger('allowed_dvs', 0)
        vlans_dvs = allowed_dvs(@vlan_options, hosts)
        vlans.merge!(vlans_dvs)
        rails_logger('allowed_dvs', 1)
      end
      @allowed_vlan_cache = vlans
    end
    filter_by_tags(@allowed_vlan_cache, options)
  end

  def allowed_dvs(_options = {}, hosts = nil)
    @dvs_ems_connect_ok ||= {}
    @dvs_by_host ||= {}
    switches = {}
    src = get_source_and_targets
    return switches if src.blank?

    hosts = get_selected_hosts(src) if hosts.nil?

    # Find if we need to connect to the EMS to collect a host's dvs
    missing_hosts = hosts.reject { |h| @dvs_by_host.key?(h.id) }
    unless missing_hosts.blank?
      begin
        st = Time.now
        return switches if @dvs_ems_connect_ok[src[:ems].id] == false
        vim = load_ar_obj(src[:ems]).connect
        missing_hosts.each { |dest_host| @dvs_by_host[dest_host.id] = get_host_dvs(dest_host, vim) }
      rescue
        @dvs_ems_connect_ok[src[:ems].id] = false
        return switches
      ensure
        vim.disconnect if vim rescue nil
        $log.info "MIQ(#{self.class.name}.allowed_dvs) Network DVS collection completed in [#{Time.now - st}] seconds"
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

  def self.allowed_templates_vendor
    nil
  end

  def allowed_templates(options = {})
    log_header = "MIQ(#{self.class.name}#allowed_templates)"

    # Return pre-selected VM if we are called for cloning
    if [:clone_to_vm, :clone_to_template].include?(request_type)
      return [VmOrTemplate.find_by_id(get_value(@values[:src_vm_id]))].compact
    end

    filter_id = get_value(@values[:vm_filter]).to_i
    if filter_id == @allowed_templates_filter && (options[:tag_filters].blank? || (@values[:vm_tags] == @allowed_templates_tag_filters))
      return @allowed_templates_cache
    end

    rails_logger('allowed_templates', 0)
    vms = []
    condition = if self.class.allowed_templates_vendor
                  ["vms.template = ? AND vms.vendor = ? AND vms.ems_id IS NOT NULL", true, self.class.allowed_templates_vendor]
                else
                  ["vms.template = ? AND vms.ems_id IS NOT NULL", true]
    end

    run_search = true
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
        $log.info "#{log_header} Filtering VM templates with the following tag_filters: <#{tag_conditions.inspect}>"
        vms = MiqTemplate.find_tags_by_grouping(tag_conditions, :ns => "/managed", :conditions => condition)
        if vms.blank?
          $log.warn "#{log_header} tag_filters returned an empty VM template list.  Tag Filters used: <#{tag_conditions.inspect}>"
          run_search = false
        else
          vms.each { |vm| $log.info "#{log_header} tag_filter template returned: <#{vm.id}:#{vm.name}>  GUID: <#{vm.guid}>  UID_EMS: <#{vm.uid_ems}>" }
        end
      end
    end

    allowed_templates_list = run_search ? source_vm_rbac_filter(vms, condition) : []
    @allowed_templates_filter = filter_id
    @allowed_templates_tag_filters = @values[:vm_tags]
    rails_logger('allowed_templates', 1)
    if allowed_templates_list.blank?
      $log.warn "#{log_header} Allowed Templates is returning an empty list"
    else
      $log.warn "#{log_header} Allowed Templates is returning <#{allowed_templates_list.length}> template(s)"
      allowed_templates_list.each { |vm| $log.info "#{log_header} Allowed Template <#{vm.id}:#{vm.name}>  GUID: <#{vm.guid}>  UID_EMS: <#{vm.uid_ems}>" }
    end

    MiqPreloader.preload(allowed_templates_list, [:operating_system, :ext_management_system, {:hardware => :disks}])
    @allowed_templates_cache = allowed_templates_list.collect do |v|
      nh = MiqHashStruct.new(
        :id                     => v.id,
        :name                   => v.name,
        :guid                   => v.guid,
        :uid_ems                => v.uid_ems,
        :platform               => v.platform,
        :num_cpu                => v.num_cpu,
        :mem_cpu                => v.mem_cpu,
        :allocated_disk_storage => v.allocated_disk_storage,
        :v_total_snapshots      => v.v_total_snapshots,
        :evm_object_class       => :Vm
        )
      nh.operating_system = MiqHashStruct.new(:product_name => v.operating_system.product_name) if v.operating_system
      nh.ext_management_system = MiqHashStruct.new(:name => v.ext_management_system.name) if v.ext_management_system
      nh.datacenter_name = v.owning_blue_folder.parent_datacenter.name rescue nil if options[:include_datacenter] == true
      nh
    end
    @allowed_templates_cache
  end

  def source_vm_rbac_filter(vms, condition = nil)
    log_header = "MIQ(#{self.class.name}#source_vm_rbac)"

    filter_id = get_value(@values[:vm_filter]).to_i
    search_options = {:results_format => :objects, :userid => @requester.userid}
    search_options[:conditions] = condition unless condition.blank?
    template_msg =  "User: <#{@requester.userid}>"
    template_msg += " Role: <#{@requester.current_group.nil? ? "none" : @requester.current_group.miq_user_role.name}>  Group: <#{@requester.current_group.nil? ? "none" : @requester.current_group.description}>"
    template_msg += "  VM Filter: <#{@values[:vm_filter].inspect}>"
    template_msg += "  Passing inital template IDs: <#{vms.collect(&:id).inspect}>" unless vms.blank?
    $log.info "#{log_header} Checking for allowed templates for #{template_msg}"
    if filter_id.zero?
      Rbac.search(search_options.merge(:targets => vms, :class => VmOrTemplate)).first
    else
      MiqSearch.find(filter_id).search(vms, search_options).first
    end
  end

  def allowed_provision_types(_options = {})
    {}
  end

  def allowed_snapshots(_options = {})
    result = {}
    return result if (vm = get_source_vm).blank?
    vm.snapshots.each { |ss| result[ss.id.to_s] = ss.current? ? "#{ss.name} (Active)" : ss.name }
    result["__CURRENT__"] = " Use the snapshot that is active at time of provisioning" unless result.blank?
    result
  end

  def allowed_datastore_storage_controller(_options = {})
    {}
  end
  deprecate :allowed_datastore_storage_controller

  def allowed_datastore_aggregate(_options = {})
    {}
  end
  deprecate :allowed_datastore_aggregate

  def get_source_vm
    get_source_and_targets[:vm]
  end

  def get_source_and_targets(refresh = false)
    return @target_resource if @target_resource && refresh == false

    vm_id = get_value(@values[:src_vm_id])
    if vm_id.to_i.zero?
      @vm_snapshot_count = 0
      return @target_resource = {}
    else
      rails_logger('get_source_and_targets', 0)
      svm = VmOrTemplate.find_by_id(vm_id)
      raise "Unable to find VM with Id: [#{vm_id}]" if svm.nil?
      raise MiqException::MiqVmError, "VM/Template <#{svm.name}> with Id: <#{vm_id}> is archived and cannot be used with provisioning." if svm.archived?
      raise MiqException::MiqVmError, "VM/Template <#{svm.name}> with Id: <#{vm_id}> is orphaned and cannot be used with provisioning." if svm.orphaned?
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
    when 'linux'   then result.merge!("fields" => "Specification")
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
    log_header = "MIQ(#{self.class.name}#allowed_organizational_units)"
    ou_domain = get_value(@values[:sysprep_domain_name])
    $log.info("#{log_header} sysprep_domain_name=<#{ou_domain}>")
    return {} if ou_domain.nil?

    if ou_domain != @last_ou_domain
      $log.info("#{log_header} sysprep_domain_name=<#{ou_domain}> does not match previous=<#{@last_ou_domain}> - recomputing")
      @last_ou_domain = ou_domain
      @ldap_ous = {}
      details   = MiqProvision.get_domain_details(ou_domain, true, @requester)
      return @ldap_ous if details.nil?

      options[:host]      = details[:ldap_host]  if details.key?(:ldap_host)
      options[:port]      = details[:ldap_port]  if details.key?(:ldap_port)
      options[:basedn]    = details[:base_dn]    if details.key?(:base_dn)
      options[:user_type] = details[:user_type]  if details.key?(:user_type)
      l = MiqLdap.new(options)
      userid   = details[:bind_dn]
      password = details[:bind_password]
      if userid.nil? || password.nil?
        $log.info("#{log_header} LDAP Bind with Defaults")
        ldap_bind = l.bind_with_default
      else
        $log.info("#{log_header} LDAP Bind with userid=<#{userid}>")
        ldap_bind = l.bind(userid, password)
      end

      if ldap_bind == true
        ous = l.get_organizationalunits
        $log.info("#{log_header} LDAP OUs returned: #{ous.inspect}")
        ous.each { |ou| @ldap_ous[ou[0].dup] = ou[1].dup } if ous.kind_of?(Array)
      else
        $log.warn("#{log_header} LDAP Bind failed")
      end
    end

    $log.info("#{log_header} returning #{@ldap_ous.inspect}")
    @ldap_ous
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
    log_header = "MIQ(#{self.class.name}#update_custom_spec)"
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

    $log.info "#{log_header} Custom spec changed from [#{@current_spec}] to [#{selected_spec}].  Customize option:[#{@customize_option}]"

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

    # Move optional arguments into the VmdbwsSupport::ProvisionOptions object
    prov_options = VmdbwsSupport::ProvisionOptions.new(
      :values                => args[6],
      :ems_custom_attributes => args[7],
      :miq_custom_attributes => args[8],
    )
    prov_args = args[0, 6]
    prov_args << prov_options
    from_ws_ver_1_x(*prov_args)
  end

  def self.from_ws_2(*args)
    from_ws_ver_1_x(*args)
  end

  def self.from_ws_ver_1_0(version, userid, src_name, target_name, auto_approve, tags, additional_values)
    log_header = "#{name}.from_ws_ver_1_x"
    $log.info "#{log_header} Web-service provisioning starting with interface version <#{version}> for user <#{userid}>"
    values = {}
    p = new(values, userid, :use_pre_dialog => false)
    src_name_down = src_name.downcase
    src = p.send(:allowed_templates).detect { |v| v.name.downcase == src_name_down }
    raise "Source template [#{src_name}] was not found" if src.nil?
    p = class_for_source(src.id).new(values, userid, :use_pre_dialog => false)

    # Populate required fields
    p.init_from_dialog(values, userid)
    values[:src_vm_id] = [src.id, src.name]
    p.refresh_field_values(values, userid)
    values[:vm_name]          = target_name
    values[:placement_auto]   = [true, 1]
    values[:owner_first_name] = userid
    values[:owner_email]      = userid
    values[:owner_last_name]  = userid

    # Tags are passed as category|value|cat2|...  Example: cc|001|environment|test
    p.set_ws_tags(values, tags, :parse_ws_string_v1)
    p.set_ws_values(values, :ws_values, additional_values, :parse_ws_string_v1)

    if p.validate(values) == false
      errors = []
      p.fields { |_fn, f, _dn, _d| errors << f[:error] unless f[:error].nil? }
      raise "Provision failed for the following reasons:\n#{errors.join("\n")}"
    end

    p.create_request(values, userid, auto_approve)
  end

  def ws_template_fields(values, fields, ws_values)
    log_header = "MIQ(#{self.class.name}#ws_template_fields)"
    data = parse_ws_string(fields)
    ws_values = parse_ws_string(ws_values)
    placement_cluster_name = ws_values[:cluster]
    unless placement_cluster_name.blank?
      data[:placement_cluster_name] = placement_cluster_name.to_s.downcase
      $log.info "#{log_header} placement_cluster_name:<#{data[:placement_cluster_name].inspect}>"
      data[:data_centers] = EmsCluster.where("lower(name) = ?", data[:placement_cluster_name]).collect(&:v_parent_datacenter)
    end
    $log.info "#{log_header} data:<#{data.inspect}>"

    src_name =     data[:name].blank?     ? nil : data[:name].downcase
    src_guid =     data[:guid].blank?     ? nil : data[:guid].downcase
    ems_guid =     data[:ems_guid].blank? ? nil : data[:ems_guid].downcase
    data_centers = data[:data_centers]

    $log.info "#{log_header} VM Passed: <#{src_name}> <#{src_guid}> <#{ems_guid}> Datacenters:<#{data_centers.inspect}>"
    if [:clone_to_vm, :clone_to_template].include?(request_type)
      src = ws_find_template_or_vm(values, src_name, src_guid, ems_guid)
    else
      srcs = send(:allowed_templates, :include_datacenter => true).find_all do |v|
        $log.info "#{log_header} VM Detected: <#{v.name.downcase}> <#{v.guid}> <#{v.uid_ems}> Datacenter:<#{v.datacenter_name}>"
        (src_name.nil? || src_name == v.name.downcase) && (src_guid.nil? || src_guid == v.guid) && (ems_guid.nil? || ems_guid == v.uid_ems) && (data_centers.nil? || data_centers.include?(v.datacenter_name))
      end
      raise "Multiple source template were found from input data:<#{data.inspect}>" if srcs.length > 1
      src = srcs.first
    end
    raise "No source template was found from input data:<#{data.inspect}>" if src.nil?
    $log.info "#{log_header} VM Found: <#{src.name}> <#{src.guid}> <#{src.uid_ems}>  Datacenter:<#{src.datacenter_name}>"
    src
  end

  def ws_find_template_or_vm(_values, src_name, src_guid, ems_guid)
    conditions = []
    args       = []

    unless src_guid.blank?
      conditions << 'guid = ?'
      args << src_guid
    end

    unless ems_guid.blank?
      conditions << 'uid_ems = ?'
      args << ems_guid
    end

    unless src_name.blank?
      conditions << 'lower(name) = ?'
      args << src_name
    end

    conditions = [conditions.join(" AND "), *args]
    vms = VmOrTemplate.where(conditions)
    vms = source_vm_rbac_filter(vms) unless vms.blank?
    vms.first
  end

  def ws_vm_fields(values, fields)
    log_header = "MIQ(#{self.class.name}#ws_vm_fields)"
    data = parse_ws_string(fields)
    $log.info "#{log_header} data:<#{data.inspect}>"
    ws_service_fields(values, fields, data)
    ws_hardware_fields(values, fields, data)
    ws_network_fields(values, fields, data)
    ws_customize_fields(values, fields, data)
    ws_schedule_fields(values, fields, data)

    data.each { |k, v| $log.warn "#{log_header} Unprocessed key <#{k}> with value <#{v.inspect}>" }
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
    log_header = "MIQ(#{self.class.name}#ws_hardware_network_fields)"
    parse_ws_hardware_fields(:networks, /^network(\d{1,2})$/, values, data) { |n, v, _i| n[:network] = v }

    # Check and remove invalid networks specifications
    values[:networks].delete_if do |d|
      result = d[:network].blank?
      $log.warn "#{log_header} Skipping network due to blank name: <#{d.inspect}>"  if result == true
      result
    end unless values[:networks].blank?
  end

  def ws_hardware_scsi_controller_fields(values, data)
    parse_ws_hardware_fields(:ctrl_scsi, /^ctrlscsi(\d{1,2})$/, values, data) do |ctrl, value, idx|
      ctrl.merge!(:busnumber => idx, :devicetype => value)
    end
  end

  def ws_hardware_disk_fields(values, data)
    log_header = "MIQ(#{self.class.name}#ws_hardware_network_fields)"
    parse_ws_hardware_fields(:disk_scsi, /^diskscsi(\d{1,2})$/, values, data) do |disk, value, _idx|
      d_parms = value.split(':')
      disk[:bus]      = d_parms[0] || '*'
      disk[:pos]      = d_parms[1] || '*'
      disk[:sizeInMB] = d_parms[2]
    end

    # Check and remove invalid disk specifications
    values[:disk_scsi].delete_if do |d|
      result = d[:sizeInMB].to_i == 0
      $log.warn "#{log_header} Skipping disk due to invalid size: <#{d.inspect}>" if result == true
      result
    end unless values[:disk_scsi].blank?
  end

  def parse_ws_hardware_fields(hw_key, regex_filter, values, data)
    log_header = "MIQ(#{self.class.name}#parse_ws_hardware_fields)"
    data.keys.each do |k|
      key_name = k.to_s.split('.').first
      next unless key_name =~ regex_filter
      item_id = $1.to_i
      v = data.delete(k)
      $log.info "#{log_header} processing key <hardware:#{k}(#{v.class})> with value <#{v.inspect}>"

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

  def self.from_ws_ver_1_x(version, userid, template_fields, vm_fields, requester, tags, options)
    options = VmdbwsSupport::ProvisionOptions.new if options.nil?
    log_header = "#{name}.from_ws_ver_1_x"
    $log.warn "#{log_header} Web-service provisioning starting with interface version <#{version}> by requester <#{userid}>"

    init_options = {:use_pre_dialog => false, :request_type => request_type(parse_ws_string(template_fields)[:request_type])}
    data = parse_ws_string(requester)
    unless data[:user_name].blank?
      userid = data[:user_name]
      $log.warn "#{log_header} Web-service requester changed to <#{userid}>"
    end

    p = new(values = {}, userid, init_options)
    userid = p.requester.userid
    src = p.ws_template_fields(values, template_fields, options.values)
    raise "Source template [#{src_name}] was not found" if src.nil?
    # Allow new workflow class to determine dialog name instead of using the stored value from the first call.
    values.delete(:miq_request_dialog_name)
    p = class_for_source(src.id).new(values, userid, init_options)

    # Populate required fields
    p.init_from_dialog(values, userid)
    values[:src_vm_id] = [src.id, src.name]
    p.refresh_field_values(values, userid)
    values[:placement_auto] = [true, 1]

    p.ws_vm_fields(values, vm_fields)
    p.ws_requester_fields(values, requester)
    p.set_ws_tags(values, tags)    # Tags are passed as category=value|cat2=value2...  Example: cc=001|environment=test
    p.set_ws_values(values, :ws_values, options.values)
    p.set_ws_values(values, :ws_ems_custom_attributes, options.ems_custom_attributes, :parse_ws_string, :modify_key_name => false)
    p.set_ws_values(values, :ws_miq_custom_attributes, options.miq_custom_attributes, :parse_ws_string, :modify_key_name => false)

    p.validate_values(values)

    p.create_request(values, userid, values[:auto_approve])
  rescue => err
    $log.error "#{log_header}: <#{err}>"
    raise err
  end

  private

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
              load_ar_obj(allowed_hosts)
            end
    Rbac.search(:targets => hosts, :class => Host, :results_format => :objects,
                :userid => @requester.userid).first
  end

  def all_provider_hosts(src)
    ui_str = ui_lookup(:table => "ext_management_systems")
    raise "Source VM [#{src[:vm].name}] does not belong to a #{ui_str}" if src[:ems].nil?
    load_ar_obj(src[:ems]).hosts
  end

  def selected_host(src)
    raise "Unable to find Host with Id: [#{src[:host_id]}]" if src[:host].nil?
    [load_ar_obj(src[:host])]
  end

  def create_unified_pg(dvs_by_host, hosts)
    all_pgs = Hash.new { |h, k| h[k] = [] }
    hosts.each do |host|
      pgs = dvs_by_host[host.id]
      next if pgs.blank?
      pgs.each { |k, v| all_pgs[k].concat(v) }
    end

    switches = {}
    all_pgs.each do |pg, switch|
      switches["dvs_#{pg}"] = "#{pg} (#{switch.uniq.sort.join('/')})"
    end
    switches
  end
end
