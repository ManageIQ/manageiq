class ManageIQ::Providers::Vmware::InfraManager
module RefreshParser::Filter
  def find_relats_vc_data(filtered_data, mappings)
    log_header = "EMS: [#{@ems.name}], id: [#{@ems.id}]"
    _log.info "#{log_header} Getting relationships from VC data..."

    vr = {
      :ems_id => @ems.id,
      :ems_to_hosts => [],
      :ems_to_vms => [],
      :hosts_to_storages => Hash.new { |h, k| h[k] = Array.new },
      :hosts_to_vms => Hash.new { |h, k| h[k] = Array.new },
      :vm_to_storage => Hash.new { |h, k| h[k] = Array.new },

      :ems_to_folders => [],
      :ems_to_clusters => [],
      :ems_to_rps => [],
      :folders_to_folders => Hash.new { |h, k| h[k] = Array.new },
      :folders_to_clusters => Hash.new { |h, k| h[k] = Array.new },
      :folders_to_hosts => Hash.new { |h, k| h[k] = Array.new },
      :folders_to_vms => Hash.new { |h, k| h[k] = Array.new },
      :clusters_to_hosts => Hash.new { |h, k| h[k] = Array.new },
      :clusters_to_rps => Hash.new { |h, k| h[k] = Array.new },
      :hosts_to_rps => Hash.new { |h, k| h[k] = Array.new },
      :rps_to_rps => Hash.new { |h, k| h[k] = Array.new },
      :rps_to_vms => Hash.new { |h, k| h[k] = Array.new },
    }

    storage_map = mappings[:storage]
    host_map = mappings[:host]
    vm_map = mappings[:vm]
    rp_map = mappings[:rp]

    [:host, :vm, :folder, :dc, :cluster, :rp].each do |type|
      key = "ems_to_#{type == :dc ? 'folder' : type.to_s}s".to_sym
      vr[key] |= filtered_data[type].collect { |mor, data| mappings[type][mor] } unless filtered_data[type].empty?
      vr[key].delete_if { |x| x == :invalid }
    end

    filtered_data[:host].each do |h_mor, h|
      h_id = host_map[h_mor]
      next if h_id == :invalid

      s_mors = get_mors(h, 'datastore').collect { |s_mor| storage_map[s_mor] }.compact
      vr[:hosts_to_storages][h_id] = s_mors unless s_mors.empty?

      parent_type, parent_mor, parent_data = host_parent_resource(h_mor, filtered_data)
      vr[:hosts_to_rps][h_id] |= parent_data["resourcePool"].to_miq_a.collect { |r_mor| rp_map[r_mor] } if parent_type == :host_res && !parent_data.nil?
    end

    filtered_data[:vm].each do |mor, v|
      vm_id = vm_map[mor]
      next if vm_id == :invalid || v.nil?

      h_id = host_map[v.fetch_path('summary', 'runtime', 'host')]
      vr[:hosts_to_vms][h_id] << vm_id unless h_id.nil? || h_id == :invalid

      unless filtered_data[:storage].empty?
        uid = RefreshParser.normalize_vm_storage_uid(v, filtered_data[:storage])
        unless uid.blank?
          s_mor, = filtered_data[:storage].find { |mor, s| RefreshParser.normalize_storage_uid(s) == uid }
          s_id = storage_map[s_mor]
          vr[:vm_to_storage][vm_id] << s_id unless s_id.nil? || s_id == :invalid
        end
      end

    end

    [:folder, :dc, :cluster, :rp].each do |parent_type|
      filtered_data[parent_type].each do |parent_mor, data|
        children = case parent_type
        when :folder then get_mors(data, 'childEntity')
        when :dc then get_mors(data, 'hostFolder') + get_mors(data, 'vmFolder')
        when :cluster then get_mors(data, 'host') + get_mors(data, 'resourcePool')
        when :rp then get_mors(data, 'resourcePool') + get_mors(data, 'vm')
        end

        children.each do |child_mor|
          child_type, child = ems_metadata_target_by_mor(child_mor, filtered_data)
          if child_type == :host_res
            child_mor = get_mors(child, 'host')[0]
            if child_mor.nil?
              child_type = child = nil
            else
              child_type, child = ems_metadata_target_by_mor(child_mor, filtered_data)
            end
          end
          next if child.nil?

          relat_type = "#{parent_type == :dc ? 'folder' : parent_type.to_s}s_to_#{child_type == :dc ? 'folder' : child_type.to_s}s".to_sym
          next unless vr.has_key?(relat_type)

          parent_id = mappings[parent_type][parent_mor]
          child_id = mappings[child_type][child_mor]
          next if parent_id == :invalid || child_id == :invalid

          relat = vr.fetch_path(relat_type, parent_id)
          relat << child_id unless relat.nil? || relat.include?(child_id)
        end
      end
    end

    _log.info "#{log_header} Getting relationships from VC data...Complete"
    return vr
  end

  def filter_vc_data(target)
    log_header = "EMS: [#{@ems.name}], id: [#{@ems.id}]"

    # Find the target in the data
    _log.info "#{log_header} Filtering inventory for #{target.class} [#{target.name}] id: [#{target.id}]..."
    case target
    when ExtManagementSystem
      filtered_data = @vc_data

    when Host
      filtered_data = Hash.new { |h, k| h[k] = Hash.new }

      host_data = host_inv_by_host(target)
      unless host_data.nil?
        filtered_data[:host] = host_data
        filtered_data[:storage] = storage_inv_by_host_inv(host_data)
        filtered_data[:vm] = vm_data = vm_inv_by_host_inv(host_data)
        filtered_data[:folder], filtered_data[:dc], filtered_data[:cluster], filtered_data[:host_res] =
          ems_metadata_inv_by_host_inv(host_data, vm_data)
        filtered_data[:rp] = rp_inv_by_host_inv(host_data)

        # Also collect any RPs that are parents of the filtered VMs in case this Host is on a Cluster
        filtered_data[:rp].merge!(rp_metadata_inv_by_vm_inv(vm_data))
      end

    when VmOrTemplate
      filtered_data = Hash.new { |h, k| h[k] = Hash.new }

      vm_data = vm_inv_by_vm(target)
      unless vm_data.nil?
        filtered_data[:vm] = vm_data
        filtered_data[:storage] = storage_inv_by_vm_inv(vm_data)
        filtered_data[:host] = host_inv_by_vm_inv(vm_data)
        filtered_data[:folder], filtered_data[:dc], filtered_data[:cluster], filtered_data[:host_res] =
          ems_metadata_inv_by_vm_inv(vm_data)
        filtered_data[:rp] = rp_metadata_inv_by_vm_inv(vm_data)
      end

    end

    filtered_counts = filtered_data.inject({}) {|h, (k, v)| h[k] = v.blank? ? 0 : v.length; h}
    _log.info "#{log_header} Filtering inventory for #{target.class} [#{target.name}] id: [#{target.id}]...Complete - Counts: #{filtered_counts.inspect}"

    EmsRefresh.log_inv_debug_trace(filtered_data, "#{_log.prefix} #{log_header} filtered_data:", 2)

    return filtered_data
  end

  #
  # Collection methods by Active Record object
  #

  def inv_by_ar_object(inv, obj)
    mor = obj.ems_ref_obj
    return nil if mor.nil?
    data = inv[mor]
    return data.nil? ? nil : {mor => data}
  end

  def host_inv_by_host(host)
    inv_by_ar_object(@vc_data[:host], host)
  end

  def vm_inv_by_vm(vm)
    inv_by_ar_object(@vc_data[:vm], vm)
  end

  ### Collection methods by Host inv

  def storage_inv_by_host_inv(host_inv)
    storage_inv = {}
    return storage_inv if @vc_data[:storage].empty?

    host_inv.each_value do |host_data|
      get_mors(host_data, 'datastore').each do |storage_mor|
        storage_inv[storage_mor] = @vc_data[:storage][storage_mor]
      end
    end
    return storage_inv
  end

  def vm_inv_by_host_inv(host_inv)
    vm_inv = {}
    return vm_inv if @vc_data[:vm].empty?

    host_inv.each_key do |host_mor|
      found = @vc_data[:vm].find_all { |vm_mor, vm_data| vm_data && host_mor == vm_data.fetch_path('summary', 'runtime', 'host') }
      found.each { |f| vm_inv[f[0]] = f[1] }
    end
    return vm_inv
  end

  def ems_metadata_inv_by_host_inv(host_inv, vm_inv)
    inv = { :folder => {}, :dc => {}, :cluster => {}, :host_res => {} }

    # For each Host find the inventory
    host_inv.each_key do |host_mor|
      ems_metadata_inv_by_host_mor(host_mor, @vc_data).each do |type, mor, data|
        inv[type][mor] ||= data
      end
    end

    # For each VM find the "blue folder" inventory
    vm_inv.each_key do |vm_mor|
      ems_metadata_inv_by_vm_mor(vm_mor, @vc_data).each do |type, mor, data|
        inv[type][mor] ||= data
      end
    end

    return inv[:folder], inv[:dc], inv[:cluster], inv[:host_res]
  end

  def rp_inv_by_host_inv(host_inv)
    rp_inv = {}
    host_inv.each_key { |host_mor| rp_inv.merge!(rp_inv_by_host_mor(host_mor)) }
    return rp_inv
  end

  ### Collection methods by VM inv

  def storage_inv_by_vm_inv(vm_inv)
    storage_inv = {}
    return storage_inv if @vc_data[:storage].empty?

    vm_inv.each_value do |vm_data|
      get_mors(vm_data, 'datastore').each do |storage_mor|
        storage_inv[storage_mor] = @vc_data[:storage][storage_mor]
      end
    end
    return storage_inv
  end

  def host_inv_by_vm_inv(vm_inv)
    host_inv = {}
    return host_inv if @vc_data[:host].empty?

    vm_inv.each_value do |vm_data|
      next if vm_data.nil?
      host_mor = vm_data.fetch_path('summary', 'runtime', 'host')
      next if host_mor.nil?

      host = @vc_data[:host][host_mor]
      host_inv[host_mor] = host unless host.nil?
    end
    return host_inv
  end

  def ems_metadata_inv_by_vm_inv(vm_inv)
    inv = { :folder => {}, :dc => {}, :cluster => {}, :host_res => {} }

    vm_inv.each do |vm_mor, vm_data|
      # Find the inventory of the parent Host
      unless vm_data.nil?
        host_mor = vm_data.fetch_path('summary', 'runtime', 'host')
        unless host_mor.nil?
          ems_metadata_inv_by_host_mor(host_mor, @vc_data).each do |type, mor, data|
            inv[type][mor] ||= data
          end
        end
      end

      # Find the "blue folder" inventory of the VM
      ems_metadata_inv_by_vm_mor(vm_mor, @vc_data).each do |type, mor, data|
        inv[type][mor] ||= data
      end
    end

    return inv[:folder], inv[:dc], inv[:cluster], inv[:host_res]
  end

  def rp_metadata_inv_by_vm_inv(vm_inv)
    rp_inv = {}
    vm_inv.each_key do |vm_mor|
      rp_metadata_inv_by_vm_mor(vm_mor, @vc_data).each do |type, mor, data|
        rp_inv[mor] ||= data
      end
    end
    return rp_inv
  end

  ### Helper methods for collection methods

  def vm_parent_rp(vm_mor, data_source)
    parent = data_source[:rp].find { |mor, data| get_mors(data, 'vm').include?(vm_mor) }
    return nil, nil if parent.nil?
    return parent
  end

  def ems_metadata_inv_by_host_mor(host_mor, data_source)
    ems_metadata = []
    parent_mor = host_mor

    # Traverse the path from the Host's parent to the root collecting information along the way
    until parent_mor.nil?
      # Find the parent
      if parent_mor == host_mor
        parent_type, parent_mor, parent = host_parent_resource(host_mor, data_source)
      else
        parent_type, parent = ems_metadata_target_by_mor(parent_mor, data_source)
      end

      break if parent.nil?
      ems_metadata << [parent_type, parent_mor, parent]

      # Find the next parent
      parent_mor = parent['parent']
    end

    return ems_metadata
  end

  def ems_metadata_inv_by_vm_mor(vm_mor, data_source)
    ems_metadata = []
    parent_mor = vm_mor

    # Traverse the path from the vm's parent folder to the datacenter
    #   collecting information along the way
    until parent_mor.nil?
      # Find the parent
      if parent_mor == vm_mor
        parent_mor, parent = data_source[parent_type = :folder].find { |mor, data| get_mors(data, 'childEntity').include?(vm_mor) }
      else
        parent_type, parent = ems_metadata_target_by_mor(parent_mor, data_source)
      end

      break if parent.nil? || parent_type == :dc
      ems_metadata << [parent_type, parent_mor, parent]

      # Find the next parent
      parent_mor = parent['parent']
    end

    return ems_metadata
  end

  def rp_metadata_inv_by_vm_mor(vm_mor, data_source)
    rp_metadata = []
    parent_mor = vm_mor

    # Traverse the path from the VM to the parent Host or Cluster collecting information along the way
    until parent_mor.nil?
      # Find the parent
      if parent_mor == vm_mor
        parent_type = :rp
        parent_mor, parent = vm_parent_rp(parent_mor, data_source)
      else
        parent_type, parent = ems_metadata_target_by_mor(parent_mor, data_source)
      end

      break if parent.nil? || [:cluster, :host_res].include?(parent_type)
      rp_metadata << [parent_type, parent_mor, parent]

      # Find the next parent
      parent_mor = parent['parent']
    end

    return rp_metadata
  end

  def rp_inv_by_rp_inv(rp_inv)
    collected_rp_inv = {}

    # Handle cases where we pass in a mor or a complete rp object
    child_rp_mors = rp_inv.kind_of?(String) ? [rp_inv] : get_mors(rp_inv, 'resourcePool')

    child_rp_mors.each do |child_rp_mor|
      found = @vc_data[:rp][child_rp_mor]
      next if found.nil?

      collected_rp_inv[child_rp_mor] ||= found
      collected_rp_inv.merge!(rp_inv_by_rp_inv(found))
    end

    return collected_rp_inv
  end

  def rp_inv_by_host_mor(host_mor)
    parent_type, parent_mor, parent_data = host_parent_resource(host_mor, @vc_data)
    # Only find resource pools that are directly under this Host
    return parent_type == :host_res ? rp_inv_by_rp_inv(parent_data['resourcePool']) : {}
  end

  def get_mors(*args)
    RefreshParser.get_mors(*args)
  end

  def host_parent_resource(*args)
    RefreshParser.host_parent_resource(*args)
  end

  def ems_metadata_target_by_mor(*args)
    RefreshParser.inv_target_by_mor(*args)
  end
end
end
