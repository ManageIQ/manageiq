class MiqHostProvisionWorkflow < MiqRequestWorkflow
  def self.base_model
    MiqHostProvisionWorkflow
  end

  def self.automate_dialog_request
    'UI_HOST_PROVISION_INFO'
  end

  def self.default_dialog_file
    'miq_host_provision_dialogs'
  end

  def self.encrypted_options_fields
    [:root_password]
  end

  def supports_iso?
    false
  end

  def make_request(request, values, requester = nil, auto_approve = false)
    update_selected_storage_names(values)
    super
  end

  def get_source_and_targets(_refresh = false)
  end

  def update_field_visibility
    # Determine the visibility of fields based on current values and collect the fields
    # together so we can update the dialog in one pass

    # Show/Hide Fields
    f = Hash.new { |h, k| h[k] = [] }

    show_flag = get_value(@values[:addr_mode]) == 'static' ? :edit : :hide
    f[show_flag] += [:hostname, :ip_addr, :subnet_mask, :gateway]

    # Update field :display value
    f.each { |k, v| show_fields(k, v) }
  end

  def set_default_values
    super
    @values[:attached_ds] = [] if @values[:attached_ds].nil?
    get_source_and_targets
  end

  #
  # Methods for populating lists of allowed values for a field
  # => Input  - A hash containing options specific to the called method
  # => Output - A hash with the format: <value> => <value display name>
  # => New methods can be added as as needed
  #

  def allowed_hosts(_options = {})
    return @allowed_hosts_cache unless @allowed_hosts_cache.nil?

    rails_logger('allowed_hosts', 0)

    host_ids = @values[:src_host_ids]
    hosts = Host.where(:id => host_ids)

    @allowed_hosts_cache  = hosts.collect do |h|
      build_ci_hash_struct(h, [:name, :guid, :uid_ems, :ipmi_address, :mac_address])
    end
    @allowed_hosts_cache
  end

  def allowed_ws_hosts(_options = {})
    Host.where("mac_address is not NULL").select(&:ipmi_enabled)
  end

  def allowed_ems(_options = {})
    result = {}

    ManageIQ::Providers::Vmware::InfraManager.select("id, name").each do |e|
      result[e.id] = e.name
    end
    result
  end

  def allowed_clusters(_options = {})
    ems = ExtManagementSystem.find_by(:id => get_value(@values[:placement_ems_name]))
    result = {}
    return result if ems.nil?
    ems.ems_clusters.each { |c| result[c.id] = "#{c.v_parent_datacenter} / #{c.name}" }
    result
  end

  def allowed_storages(_options = {})
    result = []
    ems = ExtManagementSystem.find_by(:id => get_value(@values[:placement_ems_name]))
    return result if ems.nil?
    ems.storages.each do |s|
      next unless s.store_type == "NFS"
      s.ext_management_system = ems
      result << build_ci_hash_struct(s, [:name, :free_space, :total_space])
    end
    result
  end

  # This is for summary screen display purposes only
  def update_selected_storage_names(values)
    values[:attached_ds_names] = Storage.where(:id => values[:attached_ds]).pluck(:name)
  end

  def ws_template_fields(_values, fields)
    data = parse_ws_string(fields)
    _log.info("data:<#{data.inspect}>")

    name         =     data[:name].blank? ? nil : data[:name].downcase
    mac_address  =     data[:mac_address].blank? ? nil : data[:mac_address].downcase
    ipmi_address =     data[:ipmi_address].blank? ? nil : data[:ipmi_address].downcase

    if name.nil? && mac_address.nil? && ipmi_address.nil?
      raise _("No host search criteria values were passed.  input data:<%{data}>") % {:data => data.inspect}
    end

    _log.info("Host Passed  : <#{name}> <#{mac_address}> <#{ipmi_address}>")
    srcs = allowed_ws_hosts(:include_datacenter => true).find_all do |v|
      _log.info("Host Detected: <#{v.name.downcase}> <#{v.mac_address}> <#{v.ipmi_address}>")
      (name.nil? || name == v.name.downcase) && (mac_address.nil? || mac_address == v.mac_address.to_s.downcase) && (ipmi_address.nil? || ipmi_address == v.ipmi_address.to_s)
    end
    if srcs.length > 1
      raise _("Multiple source template were found from input data:<%{data}>") % {:data => data.inspect}
    end
    src = srcs.first

    raise _("No target host was found from input data:<%{data}>") % {:data => data.inspect} if src.nil?
    _log.info("Host Found: <#{src.name}> MAC:<#{src.mac_address}> IPMI:<#{src.ipmi_address}>")
    src
  end

  def ws_host_fields(values, fields)
    data = parse_ws_string(fields)

    _log.info("data:<#{data.inspect}>")
    ws_service_fields(values, fields, data)
    ws_environment_fields(values, fields, data)
    refresh_field_values(values)
    ws_customize_fields(values, fields, data)
    ws_schedule_fields(values, fields, data)

    data.each { |k, v| _log.warn("Unprocessed key <#{k}> with value <#{v.inspect}>") }
  end

  def ws_service_fields(values, _fields, data)
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :service)).nil?
    dlg_keys = dlg_fields.keys

    [[:pxe_server_id, :allowed_pxe_servers, [:name, :url], PxeServer], [:pxe_image_id, :allowed_pxe_images, [:name], nil]].each do |dlg_key, method, keys, klass|
      result = ws_find_matching_ci(method, keys, data.delete(dlg_key), klass)
      values[dlg_key] = result.kind_of?(Array) ? result : [result.id, result.name] unless result.nil?
    end

    data.keys.each { |key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_keys.include?(key) }
  end

  def ws_environment_fields(values, _fields, data)
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :service)).nil?
    dlg_keys = dlg_fields.keys

    [[:placement_ems_name, :allowed_ems, [:name, :hostname, :ipaddress], ExtManagementSystem]].each do |dlg_key, method, keys, klass|
      result = ws_find_matching_ci(method, keys, data.delete(dlg_key), klass)
      values[dlg_key] = result.kind_of?(Array) ? result : [result.id, result.name] unless result.nil?
    end

    dlg_key = :placement_cluster_name
    search_value = data.delete(dlg_key).to_s.downcase
    values[dlg_key] = allowed_clusters.detect { |_idx, fq_name| fq_name.to_s.downcase == search_value }

    data.keys.each { |key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_keys.include?(key) }
  end

  def ws_customize_fields(values, _fields, data)
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :customize)).nil?
    dlg_keys = dlg_fields.keys

    [[:customization_template_id, :allowed_customization_templates, [:name], nil]].each do |dlg_key, method, keys, klass|
      result = ws_find_matching_ci(method, keys, data.delete(dlg_key), klass)
      values[dlg_key] = result.kind_of?(Array) ? result : [result.id, result.name] unless result.nil?
    end

    pwd_key = :root_password
    root_pwd = data.delete(pwd_key)
    unless root_pwd.blank?
      values[pwd_key] = MiqPassword.try_encrypt(root_pwd)
    end

    data.keys.each { |key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_keys.include?(key) }
  end

  def ws_find_matching_ci(allowed_method, keys, match_str, klass)
    return nil if match_str.blank?
    match_str = match_str.to_s.downcase

    send(allowed_method).detect do |item|
      ci = item.kind_of?(Array) ? klass.find_by(:id => item[0]) : item
      keys.any? do |key|
        value = ci.send(key).to_s.downcase
        # _log.warn "<#{allowed_method}> - comparing <#{value}> to <#{match_str}>"
        value.include?(match_str)
      end
    end
  end

  def self.from_ws(*args)
    # Move optional arguments into the OpenStruct object
    prov_args = args[0, 6]
    prov_options = OpenStruct.new(:values => args[6], :ems_custom_attributes => args[7], :miq_custom_attributes => args[8])
    prov_args << prov_options
    MiqHostProvisionWorkflow.from_ws_ver_1_x(*prov_args)
  end

  def self.from_ws_ver_1_x(version, user, template_fields, vm_fields, requester, tags, options)
    options = OpenStruct.new if options.nil?
    _log.warn("Web-service host provisioning starting with interface version <#{version}> by requester <#{user.userid}>")

    init_options = {:use_pre_dialog => false, :request_type => request_type(parse_ws_string(template_fields)[:request_type])}
    data = parse_ws_string(requester)
    unless data[:user_name].blank?
      user = User.find_by_userid!(data[:user_name])
      _log.warn("Web-service requester changed to <#{user.userid}>")
    end

    p = new(values = {}, user, init_options)
    src = p.ws_template_fields(values, template_fields)

    # Populate required fields
    p.init_from_dialog(values)
    values[:src_host_ids] = [src.id]
    p.refresh_field_values(values)
    values[:placement_auto] = [true, 1]

    p.ws_host_fields(values, vm_fields)
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
end # class MiqHostProvisionWorkflow
