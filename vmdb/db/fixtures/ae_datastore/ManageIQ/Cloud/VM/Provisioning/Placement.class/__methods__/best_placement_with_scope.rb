###################################
#
# EVM Automate Method: best_placement_with_scope
#
# Notes: This method is used to find the incoming templates cluster as well as hosts and storage that have the tag category
# prov_scope = 'all' && prov_scope = <group-name>
#
# Modified for RHEVM
#
###################################
begin
  @method = 'best_placement_with_scope'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  #
  # Get variables
  #
  prov = $evm.root["miq_provision"]
  vm = prov.vm_template
  raise "#{@method} - VM not specified" if vm.nil?
  user = prov.miq_request.requester
  raise "#{@method} - User not specified" if user.nil?
  ems  = vm.ext_management_system
  raise "#{@method} - EMS not found for VM:<#{vm.name}>" if ems.nil?
  cluster = vm.ems_cluster
  raise "#{@method} - Cluster not found for VM:<#{vm.name}>" if cluster.nil?
  $evm.log("info", "#{@method} - Selected Cluster: [#{cluster.nil? ? "nil" : cluster.name}]")

  # Log space required
  # $evm.log("info", "VM=<#{vm.name}>, Space Required=<#{vm.provisioned_storage}>")

  attrs = $evm.object.attributes
  tags  = {}
  #############################
  # Get Tags that are in scope
  # Default is to look for Hosts and Datastores tagged with prov_scope = All or match to Group
  #############################
  tags["prov_scope"] = ["all", user.normalized_ldap_group]

  $evm.log("info", "#{@method} - VM=<#{vm.name}>, Space Required=<#{vm.provisioned_storage}>, group=<#{user.normalized_ldap_group}>")

  #############################
  # STORAGE LIMITATIONS
  #############################
  STORAGE_MAX_VMS      = 0
  storage_max_vms      = $evm.object['storage_max_vms']
  storage_max_vms      = storage_max_vms.strip.to_i if storage_max_vms.kind_of?(String) && !storage_max_vms.strip.empty?
  storage_max_vms      = STORAGE_MAX_VMS unless storage_max_vms.kind_of?(Numeric)
  STORAGE_MAX_PCT_USED = 100
  storage_max_pct_used = $evm.object['storage_max_pct_used']
  storage_max_pct_used = storage_max_pct_used.strip.to_i if storage_max_pct_used.kind_of?(String) && !storage_max_pct_used.strip.empty?
  storage_max_pct_used = STORAGE_MAX_PCT_USED unless storage_max_pct_used.kind_of?(Numeric)
  $evm.log("info", "#{@method} - storage_max_vms:<#{storage_max_vms}> storage_max_pct_used:<#{storage_max_pct_used}>")

  #############################
  # Set host sort order here
  # options: :active_provisioning_memory, :active_provisioning_cpu, :current_memory_usage,
  #          :current_memory_headroom, :current_cpu_usage, :random
  #############################
  HOST_SORT_ORDER = [:active_provisioning_memory, :current_memory_headroom, :random]

  #############################
  # Sort hosts
  #############################
  active_prov_data = prov.check_quota(:active_provisions)
  sort_data = []

  # Only consider hosts confined to the cluster where the template resides
  cluster.hosts.each do |h|
    sort_data << sd = [[], h.name, h]
    host_id = h.attributes['id'].to_i
    HOST_SORT_ORDER.each do |type|
      sd[0] << case type
               # Multiply values by (-1) to cause larger values to sort first
               when :active_provisioning_memory
                 active_prov_data[:active][:memory_by_host_id][host_id]
               when :active_provisioning_cpu
                 active_prov_data[:active][:cpu_by_host_id][host_id]
               when :current_memory_headroom
                 h.current_memory_headroom * -1
               when :current_memory_usage
                 h.current_memory_usage
               when :current_cpu_usage
                 h.current_cpu_usage
               when :random
                 rand(1000)
               else 0
               end
    end
  end

  sort_data.sort! { |a, b| a[0] <=> b[0] }
  hosts = sort_data.collect { |sd| sd.pop }
  $evm.log("info", "#{@method} - Sorted host Order:<#{HOST_SORT_ORDER.inspect}> Results:<#{sort_data.inspect}>")

  #############################
  # Set storage sort order here
  # options: :active_provisioning_vms, :free_space, :free_space_percentage, :random
  #############################
  STORAGE_SORT_ORDER = [:free_space, :active_provisioning_vms, :random]

  host = storage = nil
  min_registered_vms = nil
  hosts.each do |h|
    next unless h.power_state == "on"

    #############################
    # Only consider hosts that have the required tags
    #############################
    next unless tags.all? do |key, value|
      if value.kind_of?(Array)
        value.any? { |v| h.tagged_with?(key, v) }
      else
        h.tagged_with?(key, value)
      end
    end

    nvms = h.vms.length

    #############################
    # Only consider storages that have the tag category group=all
    #############################
    storages = h.storages.select do |s|
      tags.all? do |key, value|
        if value.kind_of?(Array)
          value.any? { |v| s.tagged_with?(key, v) }
        else
          s.tagged_with?(key, value)
        end
      end
    end

    $evm.log("info", "#{@method} - Evaluating storages:<#{storages.collect { |s| s.name }.join(", ")}>")

    #############################
    # Filter out storages that do not have enough free space for the VM
    #############################
    active_prov_data = prov.check_quota(:active_provisions)
    storages = storages.select do |s|
      storage_id = s.attributes['id'].to_i
      actively_provisioned_space = active_prov_data[:active][:storage_by_id][storage_id]
      if s.free_space > vm.provisioned_storage + actively_provisioned_space
        #        $evm.log("info", "Active Provision Data inspect: [#{active_prov_data.inspect}]")
        #        $evm.log("info", "Active provision space requirement: [#{actively_provisioned_space}]")
        #        $evm.log("info", "Valid Datastore: [#{s.name}], enough free space for VM -- Available: [#{s.free_space}], Needs: [#{vm.provisioned_storage}]")
        true
      else
        $evm.log("info", "#{@method} - Skipping Datastore:<#{s.name}>, not enough free space for VM:<#{vm.name}>. Available:<#{s.free_space}>, Needs:<#{vm.provisioned_storage}>")
        false
      end
    end

    #############################
    # Filter out storages number of VMs is greater than the max number of VMs allowed per Datastore
    #############################
    storages = storages.select do |s|
      storage_id = s.attributes['id'].to_i
      active_num_vms_for_storage = active_prov_data[:active][:vms_by_storage_id][storage_id].length
      if (storage_max_vms == 0) || ((s.vms.size + active_num_vms_for_storage) < storage_max_vms)
        true
      else
        $evm.log("info", "#{@method} - Skipping Datastore:<#{s.name}>, max number of VMs:<#{s.vms.size + active_num_vms_for_storage}> exceeded")
        false
      end
    end

    #############################
    # Filter out storages where percent used will be greater than the max % allowed per Datastore
    #############################
    storages = storages.select do |s|
      storage_id = s.attributes['id'].to_i
      active_pct_of_storage  = ((active_prov_data[:active][:storage_by_id][storage_id]) / s.total_space.to_f) * 100
      request_pct_of_storage = (vm.provisioned_storage / s.total_space.to_f) * 100

      #      $evm.log("info", "Active Provision Data inspect: [#{s.name}]:[#{storage_id}] -- [#{active_prov_data.inspect}]")
      #      $evm.log("info", "Datastore Percent: [#{s.name}]:[#{storage_id}] -- Storage:[#{s.v_used_space_percent_of_total}]  Active:[#{active_pct_of_storage}]  Request:[#{request_pct_of_storage}]")

      if (storage_max_pct_used == 100) || ((s.v_used_space_percent_of_total + active_pct_of_storage + request_pct_of_storage) < storage_max_pct_used)
        #        $evm.log("info", "Current PCT of active provision: [#{active_pct_of_storage}]")
        #        $evm.log("info", "Valid Datastore: [#{s.name}], enough free space for VM -- Total Datastore Size: [#{s.total_space}], Available: [#{s.free_space}], Needs: [#{vm.provisioned_storage}]")
        true
      else
        $evm.log("info", "#{@method} - Skipping Datastore:<#{s.name}> percent of used space #{s.v_used_space_percent_of_total + active_pct_of_storage + request_pct_of_storage} exceeded")
        #        $evm.log("info", "Total Datastore Size: [#{s.total_space}], Total Percentage Required: ([#{s.v_used_space_percent_of_total}] + [#{active_pct_of_storage}])")
        false
      end
    end

    if min_registered_vms.nil? || nvms < min_registered_vms
      #############################
      # Sort storage to determine target datastore
      #############################
      sort_data = []
      storages.each_with_index do |s, idx|
        sort_data << sd = [[], s.name, idx]
        storage_id = s.attributes['id'].to_i
        STORAGE_SORT_ORDER.each do |type|
          sd[0] << case type
                   when :free_space
                     # Multiply values by (-1) to cause larger values to sort first
                     (s.free_space - active_prov_data[:active][:storage_by_id][storage_id]) * -1
                   when :free_space_percentage
                     active_pct_of_storage  = ((active_prov_data[:active][:storage_by_id][storage_id]) / s.total_space.to_f) * 100
                     s.v_used_space_percent_of_total + active_pct_of_storage
                   when :active_provioning_vms
                     active_prov_data[:active][:vms_by_storage_id][storage_id].length
                   when :random
                     rand(1000)
                   else 0
                   end
        end
      end

      sort_data.sort! { |a, b| a[0] <=> b[0] }
      $evm.log("info", "#{@method} - Sorted storage Order:<#{STORAGE_SORT_ORDER.inspect}>  Results:<#{sort_data.inspect}>")
      selected_storage = sort_data.first
      unless selected_storage.nil?
        selected_idx = selected_storage.last
        storage = storages[selected_idx]
        host    = h
      end

      # $evm.log("info", "Found Host:<#{h.name}> with Tags:<#{h.tags.inspect}>") if @debug

      # Stop checking if we have found both host and storage
      break if host && storage
    end

  end # END - hosts.each

  # Set Host
  obj = $evm.object
  $evm.log("info", "#{@method} - Selected Host:<#{host.nil? ? "nil" : host.name}>")
  obj["host"] = host unless host.nil?

  # Set Storage
  $evm.log("info", "#{@method} - Selected Datastore:<#{storage.nil? ? "nil" : storage.name}>")
  obj["storage"] = storage unless storage.nil?

  # Set cluster
  obj["cluster"] = cluster unless cluster.nil?
  $evm.log("info", "#{@method} - Selected Cluster:<#{cluster.nil? ? "nil" : cluster.name}>")

  # Set host and storage
  $evm.log("info", "#{@method} - vm=<#{vm.name}> host=<#{host.name}> storage=<#{storage.name}> cluster=<#{cluster.name}>")

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
