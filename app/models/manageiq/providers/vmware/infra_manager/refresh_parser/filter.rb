class ManageIQ::Providers::Vmware::InfraManager
  module RefreshParser::Filter
    def filter_vc_data(ems, target)
      log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

      # Find the target in the data
      _log.info "#{log_header} Filtering inventory for #{target.class} [#{target.name}] id: [#{target.id}]..."
      case target
      when ExtManagementSystem
        filtered_data = @vc_data

      when Host
        filtered_data = Hash.new { |h, k| h[k] = {} }

        host_data = host_inv_by_host(target)
        unless host_data.nil?
          filtered_data[:host] = host_data
          filtered_data[:storage] = storage_inv_by_host_inv(host_data)
          filtered_data[:vm] = vm_data = vm_inv_by_host_inv(host_data)
          filtered_data[:dvswitch], filtered_data[:dvportgroup] = dvswitch_and_dvportgroup_inv_by_host_inv(host_data)
          filtered_data[:folder], filtered_data[:dc], filtered_data[:cluster], filtered_data[:host_res] =
            ems_metadata_inv_by_host_inv(host_data, vm_data)
          filtered_data[:rp] = rp_inv_by_host_inv(host_data)

          # Also collect any RPs that are parents of the filtered VMs in case this Host is on a Cluster
          filtered_data[:rp].merge!(rp_metadata_inv_by_vm_inv(vm_data))
        end

      when VmOrTemplate
        filtered_data = Hash.new { |h, k| h[k] = {} }
        vm_data = vm_inv_by_vm(target)
        unless vm_data.nil?
          filtered_data[:vm] = vm_data
          filtered_data[:host] = host_inv_by_vm_inv(vm_data)
          filtered_data[:storage] = storage_inv_by_host_inv(filtered_data[:host])
          filtered_data[:dvswitch], filtered_data[:dvportgroup] = dvswitch_and_dvportgroup_inv_by_vm_inv(vm_data)
          filtered_data[:folder], filtered_data[:dc], filtered_data[:cluster], filtered_data[:host_res] =
            ems_metadata_inv_by_vm_inv(vm_data)
          filtered_data[:rp] = rp_metadata_inv_by_vm_inv(vm_data)
        end

      end

      filtered_counts = filtered_data.inject({}) { |h, (k, v)| h[k] = v.blank? ? 0 : v.length; h }
      _log.info "#{log_header} Filtering inventory for #{target.class} [#{target.name}] id: [#{target.id}]...Complete - Counts: #{filtered_counts.inspect}"

      EmsRefresh.log_inv_debug_trace(filtered_data, "#{_log.prefix} #{log_header} filtered_data:", 2)

      filtered_data
    end

    #
    # Collection methods by Active Record object
    #

    def inv_by_ar_object(inv, obj)
      mor = obj.ems_ref_obj
      return nil if mor.nil?
      data = inv[mor]
      data.nil? ? nil : {mor => data}
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
      storage_inv
    end

    def vm_inv_by_host_inv(host_inv)
      vm_inv = {}
      return vm_inv if @vc_data[:vm].empty?

      host_inv.each_key do |host_mor|
        found = @vc_data[:vm].find_all { |_vm_mor, vm_data| vm_data && host_mor == vm_data.fetch_path('summary', 'runtime', 'host') }
        found.each { |f| vm_inv[f[0]] = f[1] }
      end
      vm_inv
    end

    def dvswitch_and_dvportgroup_inv_by_host_mor(host_mor)
      dvswitch_inv    = {}
      dvportgroup_inv = {}

      dvswitches   = @vc_data[:dvswitch] || {}
      dvportgroups = @vc_data[:dvportgroup] || {}

      dvswitches.each do |dvs_mor, dvs_data|
        summary = dvs_data["summary"]
        next if summary.nil?

        dvs_hosts = RefreshParser.get_dvswitch_hosts(dvswitches, dvs_mor)
        next unless dvs_hosts.include?(host_mor)

        dvswitch_inv[dvs_mor] = dvs_data

        dvportgroups.each do |dvpg_mor, dvpg_data|
          if dvpg_data.fetch_path("config", "distributedVirtualSwitch") == dvs_mor
            dvportgroup_inv[dvpg_mor] = dvpg_data
          end
        end
      end

      return dvswitch_inv, dvportgroup_inv
    end

    def dvswitch_and_dvportgroup_inv_by_host_inv(host_inv)
      dvswitch_inv    = {}
      dvportgroup_inv = {}

      host_inv.each_key do |host_mor|
        dvs, dvp = dvswitch_and_dvportgroup_inv_by_host_mor(host_mor)

        dvswitch_inv.merge!(dvs) unless dvs.nil?
        dvportgroup_inv.merge!(dvp) unless dvp.nil?
      end

      return dvswitch_inv, dvportgroup_inv
    end

    def ems_metadata_inv_by_host_inv(host_inv, vm_inv)
      inv = {:folder => {}, :dc => {}, :cluster => {}, :host_res => {}}

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
      rp_inv
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
      host_inv
    end

    def dvswitch_and_dvportgroup_inv_by_vm_inv(vm_inv)
      dvswitch_inv    = {}
      dvportgroup_inv = {}

      vm_inv.each_value do |vm_data|
        next if vm_data.nil?

        host_mor = vm_data.fetch_path('summary', 'runtime', 'host')
        next if host_mor.nil?

        dvs, dvp = dvswitch_and_dvportgroup_inv_by_host_mor(host_mor)

        dvswitch_inv.merge!(dvs) unless dvs.nil?
        dvportgroup_inv.merge!(dvp) unless dvp.nil?
      end

      return dvswitch_inv, dvportgroup_inv
    end

    def ems_metadata_inv_by_vm_inv(vm_inv)
      inv = {:folder => {}, :dc => {}, :cluster => {}, :host_res => {}}

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
        rp_metadata_inv_by_vm_mor(vm_mor, @vc_data).each do |_type, mor, data|
          rp_inv[mor] ||= data
        end
      end
      rp_inv
    end

    ### Helper methods for collection methods

    def vm_parent_rp(vm_mor, data_source)
      parent = data_source[:rp].find { |_mor, data| get_mors(data, 'vm').include?(vm_mor) }
      return nil, nil if parent.nil?
      parent
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

      ems_metadata
    end

    def ems_metadata_inv_by_vm_mor(vm_mor, data_source)
      ems_metadata = []
      parent_mor = vm_mor

      # Traverse the path from the vm's parent folder to the datacenter
      #   collecting information along the way
      until parent_mor.nil?
        # Find the parent
        if parent_mor == vm_mor
          parent_mor, parent = data_source[parent_type = :folder].find { |_mor, data| get_mors(data, 'childEntity').include?(vm_mor) }
        else
          parent_type, parent = ems_metadata_target_by_mor(parent_mor, data_source)
        end

        break if parent.nil? || parent_type == :dc
        ems_metadata << [parent_type, parent_mor, parent]

        # Find the next parent
        parent_mor = parent['parent']
      end

      ems_metadata
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

      rp_metadata
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

      collected_rp_inv
    end

    def rp_inv_by_host_mor(host_mor)
      parent_type, parent_mor, parent_data = host_parent_resource(host_mor, @vc_data)
      # Only find resource pools that are directly under this Host
      parent_type == :host_res ? rp_inv_by_rp_inv(parent_data['resourcePool']) : {}
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
