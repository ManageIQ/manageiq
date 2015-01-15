module VmdbwsOps
  #
  # Automate web services
  #

  def EVM_get(token, uri)
    puts "MIQ(evm_get): enter >> token=[#{token}] uri=[#{uri}]"
    MiqAeEngine::MiqAeWorkspace.evmget(token, uri)
  end

  def EVM_set(token, uri, value)
    puts "MIQ(evm_set): enter >> token=[#{token}] uri=[#{uri}] value=[#{value}]"
    MiqAeEngine::MiqAeWorkspace.evmset(token, uri, value)
  end

  #
  # Insight web services
  #

  def EVM_ping(data)
    $log.info "MIQ(miq_ping): enter"
    t0 = Time.now
    $log.info "MIQ(miq_ping): data: #{data}"
    $log.info "MIQ(miq_ping): exit, elapsed time [#{Time.now - t0}] seconds"
    true
  end

  def EVM_vm_list(hostId)
    $log.info "MIQ(vm_list): enter, hostId: [#{hostId}]"
    t0 = Time.now
    if ["", "*", "all", "none"].include?(hostId.to_s.strip.downcase)
      result = VmOrTemplate.find(:all)
    else
      host = Host.find_by_guid(hostId)
      raise "unable to find host with id: [#{hostId}]" if host.nil?

      $log.info "MIQ(vm_list): Found host name: [#{host.name}]"
      result = host.vms
    end
    $log.info "MIQ(vm_list): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_host_list
    $log.info "MIQ(host_list): enter"
    t0 = Time.now
      result = Host.find(:all)
    $log.info "MIQ(host_list): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_cluster_list
    $log.info "MIQ(cluster_list): enter"
    t0 = Time.now
      result = EmsCluster.find(:all)
    $log.info "MIQ(cluster_list): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_resource_pool_list
    $log.info "MIQ(resource_pool_list): enter"
    t0 = Time.now
      result = ResourcePool.find(:all)
    $log.info "MIQ(resource_pool_list): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_datastore_list
    $log.info "MIQ(datastore_list): enter"
    t0 = Time.now
      result = Storage.find(:all)
    $log.info "MIQ(datastore_list): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_vm_software(vmGuid)
    $log.info "MIQ(vm_software): enter"
    t0 = Time.now
    vm = FindVmByGuid(vmGuid)

    result = vm.guest_applications
    $log.info "MIQ(vm_software): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_vm_accounts(vmGuid)
    $log.info "MIQ(vm_accounts): enter"
    t0 = Time.now
    vm = FindVmByGuid(vmGuid)

    result = vm.accounts.collect {|acct| VmAccounts.new(:name => acct.name, :type => acct.accttype)}
    $log.info "MIQ(vm_accounts): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_get_host(hostguid)
    $log.info "MIQ(EVM_get_host): enter"
    t0 = Time.now
    host = Host.find_by_guid(hostguid)
    ret = host.nil? ? nil : Host.new(:name => host.name, :guid => host.guid, :vmm_vendor => host.vmm_vendor)
    $log.info "MIQ(EVM_get_host): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def EVM_get_hosts(emsGuid)
    $log.info "MIQ(EVM_get_hosts): enter"
    t0 = Time.now
    ret = Host.find(:all)
    $log.info "MIQ(EVM_get_hosts): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def EVM_get_cluster(clusterId)
    $log.info "MIQ(EVM_get_cluster): enter"
    t0 = Time.now
    cluster = EmsCluster.find_by_id(clusterId)
    ret = cluster.nil? ? nil : EmsCluster.new(:name => cluster.name )
    $log.info "MIQ(EVM_get_cluster): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def EVM_get_clusters(emsId = nil)
    $log.info "MIQ(EVM_get_clusters): enter"
    t0 = Time.now
    ret = emsId.nil? ? EmsCluster.find(:all) : EmsCluster.find_by_ems_id(emsId)
    $log.info "MIQ(EVM_get_clusters): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def EVM_get_resource_pool(resourcepoolId)
    $log.info "MIQ(EVM_get_resource_pool): enter"
    t0 = Time.now
    resourcepool = ResourcePool.find_by_id(resourcepoolId)
    ret = resourcepool.nil? ? nil : ResourcePool.new(:name => resourcepool.name )
    $log.info "MIQ(EVM_get_resource_pool): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def EVM_get_resource_pools(emsGuid)
    $log.info "MIQ(EVM_get_resource_pools): enter"
    t0 = Time.now
    ret = ResourcePool.find(:all)
    $log.info "MIQ(EVM_get_resource_pools): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def EVM_get_datastore(datastoreId)
    $log.info "MIQ(EVM_get_datastore): enter"
    t0 = Time.now
    datastore = Storage.find_by_id(datastoreId)
    ret = datastore.nil? ? nil : Storage.new(:name => datastore.name )
    $log.info "MIQ(EVM_get_datastore): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def EVM_get_datastores(emsGuid)
    $log.info "MIQ(EVM_get_datastores): enter"
    t0 = Time.now
    ret = Storage.find(:all)
    $log.info "MIQ(EVM_get_datastores): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def EVM_get_vm(vmGuid)
    $log.info "MIQ(EVM_get_vm): enter"
    t0 = Time.now
    vm = FindVmByGuid(vmGuid)
    $log.info "MIQ(EVM_get_vm): exit, elapsed time [#{Time.now - t0}] seconds"
    vm
  end

  def EVM_get_vms(hostId)
    $log.info "MIQ(EVM_get_vms): enter"
    t0 = Time.now
    ret = VmOrTemplate.find(:all)
    $log.info "MIQ(EVM_get_vms): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def EVM_delete_vm_by_name(name)
    $log.info "MIQ(EVM_delete_vm_by_name): enter"
    t0 = Time.now
    vm = VmOrTemplate.find_by_name(name)

    if vm
      vm.destroy
      ret = true
    else
      ret = false
    end
    $log.info "MIQ(EVM_delete_vm_by_name): exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  #
  # Control web services
  #

  def EVM_smart_start(vmGuid)
    t0 = Time.now
    $log.info "MIQ(EVM_smart_start): enter, vmGuid: [#{vmGuid}]"
    vm = FindVmByGuid(vmGuid)

    return VmdbwsSupport::VmCmdResult.new(:result => false, :reason => "VM [#{vm.name}] is already powered on") if vm.state == "on"

    result = VmdbwsSupport::VmCmdResult.new(:result => true, :reason => "VM [#{vm.name}] starting")
    begin
      vm.start
    rescue => err
      result.result = false
      result.reason = err
    end
    $log.info "MIQ(EVM_smart_start): result: [#{result.result}], #{result.reason}"
    $log.info "MIQ(EVM_smart_start): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_smart_stop(vmGuid)
    t0 = Time.now
    $log.info "MIQ(EVM_smart_stop): enter, vmGuid: [#{vmGuid}]"
    vm = FindVmByGuid(vmGuid)

    return VmdbwsSupport::VmCmdResult.new(:result => false, :reason => "VM [#{vm.name}] is already powered off") if vm.state == "off"

    result = VmdbwsSupport::VmCmdResult.new(:result => true, :reason => "VM [#{vm.name}] stopping")
    begin
      vm.stop
    rescue => err
      result.result = false
      result.reason = err
    end
    $log.info "MIQ(EVM_smart_start): result: [#{result.result}], #{result.reason}"
    $log.info "MIQ(EVM_smart_start): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_smart_suspend(vmGuid)
    t0 = Time.now
    $log.info "MIQ(EVM_smart_suspend): enter, vmGuid: [#{vmGuid}]"
    vm = FindVmByGuid(vmGuid)

    return VmdbwsSupport::VmCmdResult.new(:result => false, :reason => "VM [#{vm.name}] is already suspended of powered off") if vm.state == "off" || vm.state == "suspended"

    result = VmdbwsSupport::VmCmdResult.new(:result => true, :reason => "VM [#{vm.name}] starting")
    begin
      vm.suspend
    rescue => err
      result.result = false
      result.reason = err
    end
    $log.info "MIQ(EVM_smart_start): result: [#{result.result}], #{result.reason}"
    $log.info "MIQ(EVM_smart_start): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_policy_list(hostId)
    $log.info "MIQ(policy_list): enter"
    t0 = Time.now
    if ["*", "all", "none"].include?(hostId.downcase)
      result = Policy.find(:all).collect {|p| PolicyList.new(:guid => p.guid, :name => p.name, :description => p.description)}
    else
      host = Host.find_by_guid(hostId)
      raise "unable to find host with id: [#{hostId}]" if host.nil?

      $log.info "MIQ(policy_list): Found host name: [#{host.name}]"
      result = host.get_policies.collect {|p| PolicyList.new(:guid => p.guid, :name => p.name, :description => p.description)}
    end
    $log.info "MIQ(policy_list): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_vm_rsop(vmGuid, policy)
    $log.info "MIQ(vm_rsop): enter"

    t0 = Time.now
    vm = FindVmByGuid(vmGuid)

    pol = Policy.find_by_name(policy)
    raise "unable to find policy named: [#{policy}]" if pol.nil?

    $log.info "MIQ(vm_rsop): Found vm name: [#{vm.name}]"
    result = vm.passes_policy?([policy])
    $log.info "MIQ(vm_rsop): exit, elapsed time [#{Time.now - t0}] seconds"
    return VmRsop.new(:result => result, :reason => pol.description)
  end

  def EVM_add_lifecycle_event(event, status, message, guid, location, created_by)
    $log.info "MIQ(add_lifecycle_event): enter"
    t0 = Time.now

    identifier = ""

    # Set VM lookup identifier to use the vm guid if provided, otherwise use the location
    unless guid.blank?
      identifier = "guid"
    else
      raise "A GUID or VM location must be provided" if location.blank?
      identifier = "location"
    end
    $log.info "MIQ(add_lifecycle_event): VM Lookup by [#{identifier}] with value [#{identifier.inspect}]"

    ## find the vm by identifier
    case identifier.downcase
    when "guid"
      value = guid
      vm = FindVmByGuid(guid)
    when "location"
      value = location
      # find_by_full_location method handles the parsing of the locations containing datastores, and finds the associated vm on that storage
      vm = VmOrTemplate.find_by_full_location(location)
    else
      raise "Unknown identifier #{identifier}"
    end
    $log.warn "MIQ(add_lifecycle_event): Unable to find vm by [#{identifier}] with value [#{identifier.inspect}]" if vm.nil?

    # create a hash of event data to give to the model for creation of the event
    event_hash = {
      :event => event,
      :status => status,
      :message => message,
      :location => location,
      :created_by => created_by
    }
    event = LifecycleEvent.create_event(vm, event_hash)

    # log if the event was created
    if event
      if vm.blank?
        msg = "Lifecycle event added for unknown vm"
      else
        msg = "Lifecycle event added for vm name: [#{vm.name}] with id: [#{vm.id}]"
      end
      result = true
      $log.info "MIQ(add_lifecycle_event): #{msg}"
    else
      result =false
    end
    $log.info "MIQ(add_lifecycle_event): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  # TODO: Change name to guid
  def EVM_get_policy(name)
    t0 = Time.now
    $log.info "MIQ(get_policy): enter"
    result = Policy.find_by_name(name)
    $log.info "MIQ(get_policy): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_event_list(policyId)
    $log.info "MIQ(EVM_event_list): enter"
    t0 = Time.now
    if ["*", "all", "none"].include?(policyId.downcase)
      result = MiqEvent.find(:all).collect {|ent| EventList.new(:guid => ent.guid, :name => ent.name)}
    else
      policy = Policy.find_by_guid(policyId)
      raise "unable to find policy with id: [#{policyId}]" if policy.nil?

      $log.info "MIQ(EVM_event_list): Found policy name: [#{policy.name}]"
      result = policy.events.collect {|ent| EventList.new(:guid => ent.guid, :name => ent.name)}
    end
    $log.info "MIQ(EVM_event_list): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_condition_list(policyId)
    $log.info "MIQ(EVM_condition_list): enter"
    t0 = Time.now
    if ["*", "all", "none"].include?(policyId.downcase)
      result = Condition.find(:all).collect {|ent| ConditionList.new(:guid => ent.guid, :name => ent.name)}
    else
      policy = Policy.find_by_guid(policyId)
      raise "unable to find policy with id: [#{policyId}]" if policy.nil?

      $log.info "MIQ(EVM_condition_list): Found policy name: [#{policy.name}]"
      result = policy.conditions.collect {|ent| ConditionList.new(:guid => ent.guid, :name => ent.name)}
    end
    $log.info "MIQ(EVM_condition_list): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_action_list(policyId)
    $log.info "MIQ(EVM_action_list): enter"
    t0 = Time.now
    if ["*", "all", "none"].include?(policyId.downcase)
      result = MiqAction.find(:all).collect {|ent| ActionList.new(:guid => ent.guid, :name => ent.name)}
    else
      policy = Policy.find_by_guid(policyId)
      raise "unable to find policy with id: [#{policyId}]" if policy.nil?

      $log.info "MIQ(EVM_action_list): Found policy name: [#{policy.name}]"
      result = policy.miq_actions.collect {|ent| ActionList.new(:guid => ent.guid, :name => ent.name)}
    end
    $log.info "MIQ(EVM_action_list): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_assign_policy(policyId, hostId)
    $log.info "MIQ(EVM_assign_policy): enter"
    t0 = Time.now

    policy = Policy.find_by_guid(policyId)
    raise "unable to find policy with id: [#{policyId}]" if policy.nil?

    host = Host.find_by_guid(hostId)
    raise "unable to find host with id: [#{hostId}]" if host.nil?

    result = true
    host.add_policy(policy)

    $log.info "MIQ(EVM_assign_policy): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_unassign_policy(policyId, hostId)
    $log.info "MIQ(EVM_assign_policy): enter"
    t0 = Time.now

    policy = Policy.find_by_guid(policyId)
    raise "unable to find policy with id: [#{policyId}]" if policy.nil?

    host = Host.find_by_guid(hostId)
    raise "unable to find host with id: [#{hostId}]" if host.nil?

    result = true
    host.remove_policy(policy)

    $log.info "MIQ(EVM_assign_policy): exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def EVM_provision_request(src_name, target_name, auto_approve, tags, additional_values)
    # MiqProvisionWorkflow.from_ws will raise an error, otherwise it is successful
    MiqProvisionWorkflow.from_ws("1.0", @username, src_name, target_name, auto_approve, tags, additional_values)
    true
  end

  def EVM_provision_request_ex(version_str, template_fields, vm_fields, requester, tags, additional_values, ems_custom_attrs, miq_custom_attrs)
    # MiqProvisionWorkflow.from_ws will raise an error, otherwise it is successful
    MiqProvisionWorkflow.from_ws(version_str, @username, template_fields, vm_fields, requester, tags,
                                 additional_values, ems_custom_attrs, miq_custom_attrs)
    true
  end

  def CreateAutomationRequest(version_str, uri_parts, parms, requester)
    # AutomateRequest.create_from_ws will raise an error, otherwise it returns an AutomateRequest instance
    ar = AutomationRequest.create_from_ws(version_str, @username, uri_parts, parms, requester)
    ar.id.to_s
  end

  def GetAutomationRequest(req_id)
    req = AutomationRequest.find_by_id(req_id)
    raise "AutomationRequest with ID=<#{req_id} (#{req_id.class.name})> was not found" if req.nil?
    return req
  end

  def GetAutomationTask(task_id)
    task = AutomationTask.find_by_id(task_id)
    raise "AutomationTask with ID=<#{task_id} (#{task_id.class.name})> was not found" if task.nil?
    return task
  end

  def EVM_host_provision_request(version_str, template_fields, host_fields, requester, tags, additional_values, ems_custom_attrs, miq_custom_attrs)
    # MiqHostProvisionWorkflow.from_ws will raise an error, otherwise it is successful
    MiqHostProvisionWorkflow.from_ws(version_str, @username, template_fields, host_fields, requester, tags,
                                 additional_values, ems_custom_attrs, miq_custom_attrs)
    true
  end

  def VmProvisionRequest(version_str, template_fields, vm_fields, requester, tags, options)
    # MiqProvisionWorkflow.from_ws_2 will raise an error, otherwise it returns a MiqRequest instance
    MiqProvisionWorkflow.from_ws_2(version_str, @username, template_fields, vm_fields, requester, tags, options)
  end

  def GetVmProvisionRequest(req_id)
    req = MiqRequest.find_by_id(req_id)
    raise "MiqRequest with ID=<#{req_id} (#{req_id.class.name})> was not found" if req.nil?
    return req
  end

  def GetVmProvisionTask(task_id)
    req = MiqRequestTask.find_by_id(task_id)
    raise "MiqRequestTask with ID=<#{task_id} (#{task_id.class.name})> was not found" if req.nil?
    return req
  end

  def EVM_vm_scan_by_property(property, value)
    VmOrTemplate.scan_by_property(property, value)
    true
  end

  def EVM_vm_event_by_property(property, value, event_type, event_message, event_time=nil)
    VmOrTemplate.event_by_property(property, value, event_type, event_message, event_time)
    true
  end

  def GetEmsList
    getKlassList(ExtManagementSystem, nil, "*")
  end

  def GetHostList(emsGuid)
    getKlassList(Host, ExtManagementSystem, emsGuid)
  end

  def GetClusterList(emsGuid)
    getKlassList(EmsCluster, ExtManagementSystem, emsGuid)
  end

  def GetResourcePoolList(emsGuid)
    getKlassList(ResourcePool, ExtManagementSystem, emsGuid)
  end

  def GetDatastoreList(emsGuid)
    getKlassList(Storage, ExtManagementSystem, emsGuid)
  end

  def GetVmList(hostGuid)
    getKlassList(VmOrTemplate, Host, hostGuid)
  end

  def getKlassList(klass, parentKlass=nil, parentGuid="*")
    log_header = "vmdbws.get#{klass.name}List"
    #puts "getKlassList klass: #{klass} parentKlass: #{parentKlass} parentGuid: #{parentGuid}"
    t0 = Time.now
    if ["*", "all", "none"].include?(parentGuid.downcase)
      $log.info "#{log_header}: enter, selection: <#{parentGuid}>"
      result = klass.find(:all)
    else
      $log.info "#{log_header}: enter, #{parentKlass.name} GUID: <#{parentGuid}>"
      parent = parentKlass.find_by_guid(parentGuid)
      raise "unable to find #{parentKlass.name} with GUID: [#{parentGuid}]" if parent.nil?

      $log.info "#{log_header}: Found #{parentKlass.name} name: [#{parent.name}]"
      result = parent.send(klass.name.underscore.pluralize)
    end
    $log.info "#{log_header}: exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end

  def getKlassListbyId(klass, parentKlass=nil, parentId="*")
    log_header = "vmdbws.get#{klass.name}ListbyId"
    t0 = Time.now
    if ["*", "all", "none"].include?(parentId.downcase)
      $log.info "#{log_header}: enter, selection: <#{parentId}>"
      result = klass.find(:all)
    else
      $log.info "#{log_header}: enter, #{parentKlass.name} ID: <#{parentId}>"
      parent = parentKlass.find_by_id(parentId)
      raise "unable to find #{parentKlass.name} with ID: [#{parentId}]" if parent.nil?

      $log.info "#{log_header}: Found #{parentKlass.name} name: [#{parent.name}]"
      result = parent.send(klass.name.underscore.pluralize)
    end
    $log.info "#{log_header}: exit, elapsed time [#{Time.now - t0}] seconds"
    return result
  end


  def FindEmsByGuid(emsGuid)
    findCIsByGuid(ExtManagementSystem, [emsGuid]).first
  end

  def FindHostsByGuid(hostGuids)
    findCIsByGuid(Host, hostGuids)
  end

  def FindHostByGuid(hostGuid)
    findCIsByGuid(Host, [hostGuid]).first
  end

  def FindClustersById(clusterIds)
    findCIsById(EmsCluster, clusterIds)
  end

  def FindClusterById(clusterId)
    findCIsById(EmsCluster, [clusterId]).first
  end

  def FindDatastoresById(datastoreIds)
    findCIsById(Storage, datastoreIds)
  end

  def FindDatastoreById(datastoreId)
    findCIsById(Storage, [datastoreId]).first
  end

  def FindResourcePoolsById(resourcepoolIds)
    findCIsById(ResourcePool, resourcepoolIds)
  end

  def FindResourcePoolById(resourcepoolId)
    findCIsById(ResourcePool, [resourcepoolId]).first
  end

  def FindVmsByGuid(vmGuids)
    findCIsByGuid(VmOrTemplate, vmGuids)
  end

  def FindVmByGuid(vmGuid)
    findCIsByGuid(VmOrTemplate, [vmGuid]).first
  end

  def GetEmsByList(list)
    getKlassByList(ExtManagementSystem, list)
  end

  def GetHostsByList(list)
    getKlassByList(Host, list)
  end

  def GetClustersByList(list)
    getKlassByListId(EmsCluster, list)
  end

  def GetDatastoresByList(list)
    getKlassByListId(Storage, list)
  end

  def GetResourcePoolsByList(list)
    getKlassByListId(ResourcePool, list)
  end

  def GetVmsByList(list)
    getKlassByList(VmOrTemplate, list)
  end

  def GetVmsByTag(tag)
    getKlassByTag(Vm, tag)
  end

  def GetTemplatesByTag(tag)
    getKlassByTag(MiqTemplate, tag)
  end

  def GetClustersByTag(tag)
    getKlassByTag(EmsCluster, tag)
  end

  def GetResourcePoolsByTag(tag)
    getKlassByTag(ResourcePool, tag)
  end

  def GetDatastoresByTag(tag)
    getKlassByTag(Storage, tag)
  end

  def VmAddCustomAttributeByFields(vmGuid, name, value, section, source)
    customAttr = VmdbwsSupport::ProxyCustomAttribute.new(:name=>name, :value=>value, :section=>section, :source=>source)
    VmAddCustomAttributes(vmGuid, [customAttr])
  end

  def VmAddCustomAttribute(vmGuid, customAttr)
    VmAddCustomAttributes(vmGuid, [customAttr])
  end

  def VmAddCustomAttributes(vmGuid, customAttrs)
    log_header = "vmdbws.VmAddCustomAttributes"

    $log.info "#{log_header}: enter"
    t0 = Time.now
    vm = FindVmByGuid(vmGuid)

    new_cust_attrs = []
    upd_cust_attrs = []
    customAttrs.each do |ca|
      unless ca.id.blank?
        vm_ca = vm.custom_attributes.detect {|c| c.id == ca.id}
        if vm_ca.nil?
          ca.id = nil
        else
          # Update exiting record with matching ID
          vm_ca.update_attributes(:name => ca.name, :value=>ca.value, :section => ca.section)
          upd_cust_attrs << vm_ca
        end
      end

      if ca.id.blank?
        vm_ca = vm.custom_attributes.detect {|c| c.section.to_s == ca.section.to_s && c.name.downcase == ca.name.downcase}
        if vm_ca.nil?
          new_cust_attrs << CustomAttribute.new(
            :name    => ca.name,
            :value   => ca.value,
            :source  => ca.source.blank? ? "EVM" : ca.source,
            :section => ca.section
          )
        else
          # Update exiting record with matching ID
          vm_ca.update_attributes(:name => ca.name, :value=>ca.value, :section => ca.section)
          upd_cust_attrs << vm_ca
        end
      end
    end

    # Send updated fields to VC
    (new_cust_attrs + upd_cust_attrs).each {|ca| vm.set_custom_field(ca.name.to_s, ca.value.to_s) if ca.source == "VC"}
    vm.custom_attributes += new_cust_attrs

    $log.info "#{log_header}: exit, elapsed time [#{Time.now - t0}] seconds"
    vm.custom_attributes(true)
  end

  def VmDeleteCustomAttribute(vmGuid, customAttr)
    vmDeleteCustomAttributes(vmGuid, [customAttr])
  end

  def VmDeleteCustomAttributes(vmGuid, customAttrs)
    log_header = "vmdbws.vmDeleteCustomAttributes"

    $log.info "#{log_header}: enter"
    t0 = Time.now
    vm = FindVmByGuid(vmGuid)

    ids = customAttrs.collect(&:id).compact
    vm.custom_attributes.each do |ca|
      if (ids.include?(ca.id.to_s))
        # Check if we need to update the EMS
        vm.set_custom_field(ca.name, '') if ca.source == 'VC'
        ca.delete
      end
    end

    $log.info "#{log_header}: exit, elapsed time [#{Time.now - t0}] seconds"
    vm.custom_attributes(true)
  end

  def VmSetOwner(vmGuid, owner)
    vm = FindVmByGuid(vmGuid)
    user = User.find_or_create_by_ldap_upn(owner)
    vm.evm_owner = user
    vm.miq_group = user.current_group unless user.nil?
    vm.save!
    true
  end

  def VmSetTag(vmGuid, category, name)
    ciSetTag(FindVmByGuid(vmGuid), category, name)
  end

  def VmGetTags(vmGuid)
    ciGetTags(FindVmByGuid(vmGuid))
  end

  def HostSetTag(hostGuid, category, name)
    ciSetTag(FindHostByGuid(hostGuid), category, name)
  end

  def HostGetTags(hostGuid)
    ciGetTags(FindHostByGuid(hostGuid))
  end

  def ClusterSetTag(clusterId, category, name)
    ciSetTag(FindClusterById(clusterId), category, name)
  end

  def ClusterGetTags(clusterId)
    ciGetTags(FindClusterById(clusterId))
  end

  def EmsSetTag(emsGuid, category, name)
    ciSetTag(FindEmsByGuid(emsGuid), category, name)
  end

  def EmsGetTags(emsGuid)
    ciGetTags(FindEmsByGuid(emsGuid))
  end

  def DatastoreSetTag(datastoreId, category, name)
    ciSetTag(FindDatastoreById(datastoreId), category, name)
  end

  def DatastoreGetTags(datastoreId)
    ciGetTags(FindDatastoreById(datastoreId))
  end

  def ResourcePoolSetTag(resourcepoolId, category, name)
    ciSetTag(FindResourcePoolById(resourcepoolId), category, name)
  end

  def ResourcePoolGetTags(resourcepoolId)
    ciGetTags(FindResourcePoolById(resourcepoolId))
  end

  def Version
    # Return version information as an array of strings
    Vmdb::Appliance.VERSION.split(".") << Vmdb::Appliance.BUILD
  end

  #
  # System methods
  #

  def vm_invoke_tasks(options)
    # TODO: Block incoming requests that are not made by 'system' User. Currently,
    # web services do not set User.current_userid.
    VmOrTemplate.invoke_tasks_queue(options.to_h)
    true
  end

  protected

  def findCIsByGuid(klass, guids)
    log_header = "vmdbws.findCIsByGuid for #{klass.name}"
    $log.info "#{log_header}: enter, guids: #{guids}"
    t0 = Time.now
    vcn = klass.virtual_column_names_symbols
    case klass
    when Host then vcn += [:custom_attributes, :ext_management_system, :resource_pools, :storages, :vms, :hardware]
    end

    Rails.logger.info("#{log_header}: loading <#{guids.to_miq_a.length}> instance(s) for GUIDs <#{guids.inspect}>")
    ret = klass.all(:conditions => {:guid => guids}, :include => vcn)
    raise "Unable to find #{klass} with GUID <#{guids.inspect}>" if ret.blank?
    Rails.logger.info("#{log_header}: returning, elapsed time [#{Time.now - t0}] seconds")
    ret
  end

  def findCIsById(klass, ids)
    log_header = "vmdbws.findCIsById for #{klass.name}"
    $log.info "#{log_header}: enter, ids: #{ids}"
    t0 = Time.now
    vcn = klass.virtual_column_names_symbols
    Rails.logger.info("#{log_header}: loading <#{ids.to_miq_a.length}> instance(s) for IDs <#{ids.inspect}>")
    ret = klass.all(:conditions => {:id => ids}, :include => vcn)
    $log.info "#{log_header}: exit, elapsed time [#{Time.now - t0}] seconds"
    raise "Unable to find #{klass} with ID <#{ids.inspect}>" if ret.blank?
    Rails.logger.info("#{log_header}: returning, elapsed time [#{Time.now - t0}] seconds")
    ret
  end

  def getKlassByList(klass, list)
    log_header = "vmdbws.get#{klass.name}ByList"

    $log.info "#{log_header}: enter"
    raise "No list provided for Find#{klass}ByList " if list.nil?

    guids = list.to_miq_a.collect(&:guid)
    findCIsByGuid(klass, guids)
  end

  def getKlassByListId(klass, list)
    log_header = "vmdbws.get#{klass.name}ByListId"

    $log.info "#{log_header}: enter"
    raise "No list provided for Find#{klass}ByListId  " if list.nil?

    ids = list.to_miq_a.collect(&:id)
    findCIsById(klass, ids)
  end

  def getKlassByTag(klass, tag)
    log_header = "getKlassbytag - vmdbws.get#{klass.name}ByTag"

    $log.info "#{log_header}: enter"
    t0 = Time.now
    ret = klass.find_tagged_with(:all => tag, :ns => '/managed').all
    $log.info "#{log_header}: exit, elapsed time [#{Time.now - t0}] seconds"
    ret
  end

  def ciSetTag(ci, category, name)
    return true if ci.is_tagged_with?(name, :ns=>"/managed/#{category}")
    !Classification.classify(ci, category, name).nil?
  end

  def ciGetTags(ci)
    ns = '/managed'
    ci.tag_list(:ns => ns).split(' ').each_with_object([]) do |tag_path, tags|
      parts = tag_path.split('/')
      cat = Classification.find_by_name(parts.first, nil)
      next unless cat && cat.show
      cat_descript = cat.description
      tag_descript = Classification.find_by_name(tag_path, nil).description
      tags << {:category => parts.first, :category_display_name => cat_descript,
               :tag_name => parts.last,  :tag_display_name => tag_descript,
               :tag_path =>  File.join(ns, tag_path), :display_name => "#{cat_descript}: #{tag_descript}"
               }
    end
  end
end
