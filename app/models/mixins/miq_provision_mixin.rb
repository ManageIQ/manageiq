module MiqProvisionMixin
  RESOURCE_CLASS_KEY_MAP = {
    # Infrastructure
    "Host"                                           => [:hosts,                   :placement_host_name],
    "Storage"                                        => [:storages,                :placement_ds_name],
    "StorageProfile"                                 => [:storage_profiles,        :placement_storage_profile],
    "EmsCluster"                                     => [:clusters,                :placement_cluster_name],
    "ResourcePool"                                   => [:resource_pools,          :placement_rp_name],
    "EmsFolder"                                      => [:folders,                 :placement_folder_name],
    "PxeServer"                                      => [:pxe_servers,             :pxe_server_id],
    "PxeImage"                                       => [:pxe_images,              :pxe_image_id],
    "WindowsImage"                                   => [:windows_images,          :pxe_image_id],
    "CustomizationTemplate"                          => [:customization_templates, :customization_template_id],
    "IsoImage"                                       => [:iso_images,              :iso_image_id],
    "CustomizationSpec"                              => [:customization_specs,     :sysprep_custom_spec],

    # Cloud
    "AvailabilityZone"                               => [:availability_zones,      :placement_availability_zone],
    "CloudTenant"                                    => [:cloud_tenants,           :cloud_tenant],
    "CloudNetwork"                                   => [:cloud_networks,          :cloud_network],
    "CloudSubnet"                                    => [:cloud_subnets,           :cloud_subnet],
    "SecurityGroup"                                  => [:security_groups,         :security_groups],
    "ResourceGroup"                                  => [:resource_groups,         :resource_group],
    "FloatingIp"                                     => [:floating_ip_addresses,   :floating_ip_address],
    "Flavor"                                         => [:instance_types,          :instance_type],
    "ManageIQ::Providers::CloudManager::AuthKeyPair" => [:guest_access_key_pairs,  :guest_access_key_pair]
  }.freeze

  def tag_ids
    options[:vm_tags]
  end

  def tag_ids=(value)
    options[:vm_tags] = value
  end

  def register_automate_callback(callback_name, automate_uri)
    _log.info("Registering callback: [#{callback_name}] with Automate entry point: [#{automate_uri}]")
    options[:callbacks] ||= {}
    options[:callbacks][callback_name.to_sym] = automate_uri
    update_attribute(:options, options)
  end

  def set_vm_notes(notes)
    update_attribute(:options, options.merge(:vm_notes => notes))
  end

  def call_automate_event(*args)
    super
  rescue MiqAeException::Error
    # Allow the state machine to complete.
  end

  def get_owner
    @owner ||= begin
      email = get_option(:owner_email).try(:downcase)
      return if email.blank?
      User.lookup_by_lower_email(email, get_user).tap do |owner|
        owner.current_group_by_description = get_option(:owner_group) if owner
      end
    end
  end

  def workflow_class
    MiqProvisionWorkflow.class_for_source(source)
  end

  def eligible_resources(rsc_type)
    prov_options = options.dup
    prov_options[:placement_auto] = [false, 0]
    result = nil
    workflow(prov_options, :skip_dialog_load => true) do |prov_wf|
      klass = resource_type_to_class(rsc_type)

      allowed_method = "allowed_#{rsc_type}"
      unless prov_wf.respond_to?(allowed_method)
        error_str = _("Provision workflow does not contain the expected method <%{method}>") % {:method => allowed_method}
        raise MiqException::MiqProvisionError, error_str
      end

      result = prov_wf.send(allowed_method)
      result = result.collect { |rsc| eligible_resource_lookup(klass, rsc) }

      data = result.collect { |rsc| "#{rsc.id}:#{resource_display_name(rsc)}" }
      _log.info("returning <#{rsc_type}>:<#{data.join(', ')}>")
    end
    result
  end

  # Helper method to determines the ID for a resource and load the active-record object.
  # The rsc_data will either be in the form of a HashStruct with an 'id' property or as an array
  # in the format [id, display_name].  Additionally, some IDs can contain model metadata in the
  # form "class_name::id".
  def eligible_resource_lookup(klass, rsc_data)
    ci_id = rsc_data.kind_of?(Array) ? rsc_data.first : rsc_data.id
    ci_id = ci_id.split("::").last if ci_id.to_s.include?("::")
    klass.find_by(:id => ci_id)
  end
  private :eligible_resource_lookup

  def set_resource(rsc, _options = {})
    return if rsc.nil?

    key, rsc_type, value = resource_construct_value(rsc)
    _log.info("option <#{key}> being set to <#{value.inspect}>")
    options[key] = value

    post_customization_templates(rsc.id) if rsc_type == :customization_templates

    update_attribute(:options, options)
  end

  def set_resources(rscs, _options = {})
    return unless rscs.present?

    key = nil
    items = []
    rscs.compact.each do |rsc|
      key, _rsc_type, value = resource_construct_value(rsc)
      items << value
    end

    options[key] = items.flatten
    _log.info("option <#{key}> being set to <#{items.inspect}>")
    update(:options => options)
  end

  def post_customization_templates(template_id)
    options[:customization_template_script] = CustomizationTemplate.find_by(:id => template_id).try(:script)
  end

  def set_folder(folder)
    return nil if folder.blank?

    result = if folder.kind_of?(MiqAeMethodService::MiqAeServiceEmsFolder)
               folder
             elsif folder.kind_of?(Array) && folder.length == 2 && folder.first.kind_of?(Integer)
               MiqAeMethodService::MiqAeServiceEmsFolder.find(folder.first)
             else
               find_path = Array.wrap(folder.presence).join('/')
               found = eligible_resources(:folders).detect do |f|
                 folder_path = f.folder_path(:exclude_root_folder => true, :exclude_non_display_folders => true)
                 folder_path.casecmp(find_path).zero?
               end
               MiqAeMethodService::MiqAeServiceEmsFolder.find(found.id) if found
             end

    result.tap { set_resource(result) }
  end

  def get_folder_paths
    # If the host is selected we need to limit the folders returned based on the data-center
    # the host is in.  Otherwise we return all folders in all data-centers.
    host = get_option(:placement_host_name)
    if host.nil?
      vm_template.ext_management_system.get_folder_paths
    else
      dest_host = Host.find(host)
      vm_template.ext_management_system.get_folder_paths(dest_host.owning_datacenter)
    end
  end

  def get_source_vm
    vm_id = get_option(:src_vm_id)
    raise _("Source VM not provided") if vm_id.nil?
    svm = VmOrTemplate.find_by(:id => vm_id)
    raise _("Unable to find VM with Id: [%{vm_id}]") % {:vm_id => vm_id} if svm.nil?
    svm
  end

  def get_source_name
    get_option_last(:src_vm_id)
  end

  def get_new_disks
    new_disks_req = options[:disk_scsi]
    return [] if new_disks_req.blank?

    svm = get_source_vm
    scsi_idx = svm.hardware.disks.collect { |d| d.location if d.controller_type == "scsi" }.compact

    # Add any disk that does not already exist at the same location
    new_disks_req.reject { |d| scsi_idx.include?("#{d[:bus]}:#{d[:pos]}") }
  end

  def set_customization_spec(custom_spec_name, override = false)
    if custom_spec_name.nil?
      disable_customization_spec
    else
      custom_spec_name = custom_spec_name.name unless custom_spec_name.kind_of?(String)
      options = self.options.dup
      workflow do |prov_wf|
        options[:sysprep_enabled] = %w(fields Specification)
        prov_wf.init_from_dialog(options)
        prov_wf.get_all_dialogs
        prov_wf.allowed_customization_specs
        prov_wf.get_timezones
        prov_wf.refresh_field_values(options)
        custom_spec = prov_wf.allowed_customization_specs.detect { |cs| cs.name == custom_spec_name }
        if custom_spec.nil?
          raise MiqException::MiqProvisionError,
                _("Customization Specification [%{name}] does not exist.") % {:name => custom_spec_name}
        end

        options[:sysprep_custom_spec] = [custom_spec.id, custom_spec.name]
        override_value = override == false ? [false, 0] : [true, 0]
        options[:sysprep_spec_override] = override_value
        # Call refresh_field_values a second time so it recognizes the config change
        # and loads the defaults the customization spec settings
        prov_wf.refresh_field_values(options)

        self.options.keys.each do |key|
          v_old = self.options[key]
          v_new = options[key]
          _log.info("option <#{key}> was changed from <#{v_old.inspect}> to <#{v_new.inspect}>") unless v_old == v_new
        end

        update_attribute(:options, options)
      end
    end

    true
  end

  def disable_customization_spec
    options[:sysprep_enabled] = ['disabled', '(Do not customize)']
    update_attribute(:options, options)
  end

  def target_type
    return 'template' if provision_type == 'clone_to_template'
    'vm'
  end

  def source_type
    vm_template.kind_of?(MiqTemplate) ? 'template' : 'vm'
  end

  def set_nic_settings(idx, nic_hash, value = nil)
    if idx.to_i > 0
      set_options_config_array(:nic_settings, idx, nic_hash, value)
    else
      # if the index is 0 then we need to merge the hash directly into the options hash
      nic_hash.kind_of?(Hash) ? options.merge!(nic_hash) : options[nic_hash] = value
      update_attribute(:options, options)
    end
  end

  def set_network_adapter(idx, net_hash, value = nil)
    set_options_config_array(:networks, idx, net_hash, value)
  end

  def set_options_config_array(key, idx, hash, value = nil)
    idx = idx.to_i
    items = options[key] || []
    items[idx] = {} if items[idx].nil?
    hash.kind_of?(Hash) ? items[idx].merge!(hash) : items[idx][hash] = value
    options[key] = items
    update_attribute(:options, options)
  end

  def request_options
    skip_keys = [:vm_tags]
    options.collect do |k, v|
      if skip_keys.include?(k)
        nil
      elsif v.kind_of?(Array)
        if v.length == 2
          format_web_service_property(k, v[0])
        end
      elsif v.kind_of?(Hash)
        nil
      else
        format_web_service_property(k, v)
      end
    end.compact
  end

  def format_web_service_property(key, value)
    return nil if value.kind_of?(Hash)
    return nil if value.blank?
    value = value.iso8601 if value.kind_of?(Time)
    {:key => key.to_s, :value => value.to_s}
  end

  private

  def resource_type_to_class(rsc_type)
    RESOURCE_CLASS_KEY_MAP.detect { |_k, v| v.first == rsc_type }.first.to_s.constantize
  end

  def class_to_resource_type_and_key(rsc_class)
    RESOURCE_CLASS_KEY_MAP[rsc_class]
  end

  def resource_display_name(rsc)
    return rsc.name    if rsc.respond_to?(:name)
    ''
  end

  def resource_construct_value(rsc)
    rsc_class = resource_class(rsc)
    rsc_type, key = class_to_resource_type_and_key(rsc_class)
    if rsc_type.nil?
      raise _("Unsupported resource type <%{class_name}> passed to set_resource for provisioning.") %
            {:class_name => rsc.class.base_class.name}
    end

    rsc_name = resource_display_name(rsc)
    result   = eligible_resources(rsc_type).any? { |r| r.id == rsc.id }

    if result == false
      resource_str = "<#{rsc_class}> <#{rsc.id}:#{rsc_name}>"
      raise _("Resource %{resource_name} is not an eligible resource for this provisioning instance.") %
            {:resource_name => resource_str}
    end
    value = construct_value(key, rsc_class, rsc.id, rsc_name)
    [key, rsc_type, value]
  end

  def construct_value(key, rsc_class, rsc_id, rsc_name)
    case key
    when :security_groups then [rsc_id]
    when :pxe_image_id    then ["#{rsc_class}::#{rsc_id}", rsc_name]
    else [rsc_id, rsc_name]
    end
  end

  def resource_class(rsc)
    if rsc.kind_of?(MiqAeMethodService::MiqAeServiceManageIQ_Providers_CloudManager_AuthKeyPair)
      return 'ManageIQ::Providers::CloudManager::AuthKeyPair'
    end
    $1 if rsc.class.base_class.name =~ /::MiqAeService(.*)/
  end
end
