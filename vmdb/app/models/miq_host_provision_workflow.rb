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

  def create_request(values, requester_id, auto_approve=false)
    event_message = "Host Provision requested by [#{requester_id}] for Host:#{values[:src_host_id].inspect}"
    super(values, requester_id, 'Host', 'host_provision_request_created', event_message, auto_approve) { update_selected_storage_names(values) }
  end

  def update_request(request, values, requester_id)
    event_message = "Host Provision request was successfully updated by [#{requester_id}] for Host:#{values[:src_host_id].inspect}"
    super(request, values, requester_id, 'Host', 'host_provision_request_updated', event_message) { update_selected_storage_names(values) }
  end

  def get_source_and_targets(refresh=false)
  end

  def update_field_visibility()
    # Determine the visibility of fields based on current values and collect the fields
    # together so we can update the dialog in one pass

    # Show/Hide Fields
    f = Hash.new { |h, k| h[k] = Array.new }

    show_flag = get_value(@values[:addr_mode]) == 'static' ? :edit : :hide
    f[show_flag] += [:hostname, :ip_addr, :subnet_mask, :gateway]

    # Update field :display value
    f.each {|k,v| show_fields(k, v)}
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

  def allowed_hosts(options={})
    log_header = "MiqHostProvisionWorkflow.allowed_hosts"
    return @allowed_hosts_cache unless @allowed_hosts_cache.nil?

    rails_logger('allowed_hosts', 0)

    host_ids = @values[:src_host_ids]
    hosts = Host.find_all_by_id(host_ids)

    @allowed_hosts_cache  = hosts.collect do |h|
      build_ci_hash_struct(h, [:name, :guid, :uid_ems, :ipmi_address, :mac_address])
    end
    return @allowed_hosts_cache
  end

  def allowed_ws_hosts(options={})
    Host.where("mac_address is not NULL").select { |h| h.ipmi_enabled }
  end

  def allowed_ems(options={})
    result = {}

    ExtManagementSystem.select("id, name").each do |e|
      result[e.id] = e.name if e.kind_of?(EmsVmware)
    end
    return result
  end

  def allowed_clusters(options={})
    ems = ExtManagementSystem.find_by_id(get_value(@values[:placement_ems_name]))
    result = {}
    return result if ems.nil?
    ems.ems_clusters.each {|c| result[c.id] = "#{c.v_parent_datacenter} / #{c.name}"}
    return result
  end

  def allowed_storages(options={})
    result = []
    ems = ExtManagementSystem.find_by_id(get_value(@values[:placement_ems_name]))
    return result if ems.nil?
    ems.storages.each do |s|
      next unless s.store_type == "NFS"
      result << build_ci_hash_struct(s, [:name, :free_space, :total_space])
    end
    return result
  end

  # This is for summary screen display purposes only
  def update_selected_storage_names(values)
    values[:attached_ds_names] = Storage.find_all_by_id(values[:attached_ds], :select => "name").collect {|h| h.name}
  end

  def ws_template_fields(values, fields)
    log_header = "#{self.class.name}.ws_template_fields"
    data = parse_ws_string(fields)
    $log.info "#{log_header} data:<#{data.inspect}>"

    name         =     data[:name].blank?         ? nil : data[:name].downcase
    mac_address  =     data[:mac_address].blank?  ? nil : data[:mac_address].downcase
    ipmi_address =     data[:ipmi_address].blank? ? nil : data[:ipmi_address].downcase

    raise "No host search criteria values were passed.  input data:<#{data.inspect}>" if name.nil? && mac_address.nil? && ipmi_address.nil?

    $log.info "#{log_header} Host Passed  : <#{name}> <#{mac_address}> <#{ipmi_address}>"
    srcs = self.send(:allowed_ws_hosts, {:include_datacenter => true}).find_all do |v|
      $log.info "#{log_header} Host Detected: <#{v.name.downcase}> <#{v.mac_address}> <#{v.ipmi_address}>"
      (name.nil? || name == v.name.downcase) && (mac_address.nil? || mac_address == v.mac_address.to_s.downcase) && (ipmi_address.nil? || ipmi_address == v.ipmi_address.to_s)
    end
    raise "Multiple source template were found from input data:<#{data.inspect}>" if srcs.length > 1
    src = srcs.first

    raise "No target host was found from input data:<#{data.inspect}>" if src.nil?
    $log.info "#{log_header} Host Found: <#{src.name}> MAC:<#{src.mac_address}> IPMI:<#{src.ipmi_address}>"
    return src
  end

  def ws_host_fields(values, fields, userid)
    log_header = "#{self.class.name}.ws_host_fields"
    data = parse_ws_string(fields)

    $log.info "#{log_header} data:<#{data.inspect}>"
    ws_service_fields(values, fields, data)
    ws_environment_fields(values, fields, data)
    self.refresh_field_values(values, userid)
    ws_customize_fields(values, fields, data)
    ws_schedule_fields(values, fields, data)

    data.each {|k, v| $log.warn "#{log_header} Unprocessed key <#{k}> with value <#{v.inspect}>"}
  end

  def ws_service_fields(values, fields, data)
    log_header = "#{self.class.name}.ws_service_fields"
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :service)).nil?
    dlg_keys = dlg_fields.keys

    [[:pxe_server_id, :allowed_pxe_servers, [:name, :url], PxeServer], [:pxe_image_id, :allowed_pxe_images, [:name], nil]].each do |dlg_key, method, keys, klass|
      result = ws_find_matching_ci(method, keys, data.delete(dlg_key), klass)
      values[dlg_key] = result.kind_of?(Array) ? result : [result.id, result.name] unless result.nil?
    end

    data.keys.each {|key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_keys.include?(key)}
  end

  def ws_environment_fields(values, fields, data)
    log_header = "#{self.class.name}.ws_environment_fields"
    return if (dlg_fields = get_ws_dialog_fields(dialog_name = :service)).nil?
    dlg_keys = dlg_fields.keys

    [[:placement_ems_name, :allowed_ems, [:name, :hostname, :ipaddress], ExtManagementSystem]].each do |dlg_key, method, keys, klass|
      result = ws_find_matching_ci(method, keys, data.delete(dlg_key), klass)
      values[dlg_key] = result.kind_of?(Array) ? result : [result.id, result.name] unless result.nil?
    end

    dlg_key = :placement_cluster_name
    search_value = data.delete(dlg_key).to_s.downcase
    values[dlg_key] = self.allowed_clusters.detect {|idx, fq_name| fq_name.to_s.downcase == search_value}

    data.keys.each {|key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_keys.include?(key)}
  end

  def ws_customize_fields(values, fields, data)
    log_header = "#{self.class.name}.ws_customize_fields"
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

    data.keys.each {|key| set_ws_field_value(values, key, data, dialog_name, dlg_fields) if dlg_keys.include?(key)}
  end

  def ws_find_matching_ci(allowed_method, keys, match_str, klass)
    log_header = "#{self.class.name}.ws_find_matching_ci"
    return nil if match_str.blank?
    match_str = match_str.to_s.downcase

    self.send(allowed_method).detect do |item|
      ci = item.kind_of?(Array) ? klass.find_by_id(item[0]) : item
      keys.any? do |key|
        value = ci.send(key).to_s.downcase
        #$log.warn "#{log_header} <#{allowed_method}> - comparing <#{value}> to <#{match_str}>"
        value.include?(match_str)
      end
    end
  end

  def self.from_ws(*args)
    version = args.first.to_f

    # Move optional arguments into the VmdbwsSupport::ProvisionOptions object
    prov_args = args[0,6]
    prov_options = VmdbwsSupport::ProvisionOptions.new(:values => args[6], :ems_custom_attributes => args[7], :miq_custom_attributes => args[8])
    prov_args << prov_options
    MiqHostProvisionWorkflow.from_ws_ver_1_x(*prov_args)
  end

  def self.from_ws_2(*args)
    MiqHostProvisionWorkflow.from_ws_ver_1_x(*args)
  end

  def self.from_ws_ver_1_x(version, userid, template_fields, vm_fields, requester, tags, options)
    log_header = "#{self.class.name}.from_ws"
    begin
      options = VmdbwsSupport::ProvisionOptions.new if options.nil?
      $log.warn "#{log_header} Web-service host provisioning starting with interface version <#{version}> by requester <#{userid}>"

      init_options = {:use_pre_dialog => false, :request_type => self.request_type(parse_ws_string(template_fields)[:request_type])}
      data = parse_ws_string(requester)
      unless data[:user_name].blank?
        userid = data[:user_name]
        $log.warn "#{log_header} Web-service requester changed to <#{userid}>"
      end

      p = self.new(values = {}, userid, init_options)
      userid = p.requester.userid
      src = p.ws_template_fields(values, template_fields)

      # Populate required fields
      p.init_from_dialog(values, userid)
      values[:src_host_ids] = [src.id]
      p.refresh_field_values(values, userid)
      values[:placement_auto] = [true, 1]

      p.ws_host_fields(values, vm_fields, userid)
      p.ws_requester_fields(values, requester)
      p.set_ws_tags(values, tags)    # Tags are passed as category=value|cat2=value2...  Example: cc=001|environment=test
      p.set_ws_values(values, :ws_values, options.values)
      p.set_ws_values(values, :ws_ems_custom_attributes, options.ems_custom_attributes, :parse_ws_string, {:modify_key_name => false})
      p.set_ws_values(values, :ws_miq_custom_attributes, options.miq_custom_attributes, :parse_ws_string, {:modify_key_name => false})

      p.validate_values(values)

      p.create_request(values, userid, values[:auto_approve])
    rescue => err
      $log.error "#{log_header}: <#{err}>"
      raise err
    end
  end

end #class MiqHostProvisionWorkflow
