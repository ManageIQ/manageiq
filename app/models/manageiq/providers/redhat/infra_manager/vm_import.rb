module ManageIQ::Providers::Redhat::InfraManager::VmImport
  extend ActiveSupport::Concern

  # source_params {
  #   vm_id
  # }
  #
  # target_params {
  #   name (optional)
  #   cluster_id
  #   storage_id
  #   sparse
  #   drivers_iso
  # }
  def import_vm(source_vm_id, target_params)
    vm = Vm.includes(:ext_management_system).find(source_vm_id)
    source_provider = vm.ext_management_system

    check_import_supported! source_provider

    auth = password_auth(source_provider)
    perform_vmware_to_ovirt_import(
      :source_vm_name    => vm.name,
      :target_vm_name    => target_params[:name],
      :username          => auth.userid,
      :password          => auth.password,
      :url               => vmware_import_url(source_provider, vm),
      :cluster_id        => EmsCluster.find(target_params[:cluster_id]).uid_ems,
      :storage_domain_id => Storage.find(target_params[:storage_id]).ems_ref_obj.split('/').last,
      :sparse            => target_params[:sparse],
      :drivers_iso       => target_params[:drivers_iso] != '' ? target_params[:drivers_iso] : nil
    )
  end

  def configure_imported_vm_networks(vm_id)
    _log.info("Configuring networks for VM: #{vm_id}")

    vm = Vm.find(vm_id)
    dc = vm.ems_cluster.parent_datacenter

    with_provider_connection :version => 4 do |conn|
      vm_network_id = first_vm_network_id(conn, dc.uid_ems)
      vnic_profile_id = vnic_profile_id_by_network_id(conn, vm_network_id)
      set_all_vm_nics_to_profile_id(conn, vm.uid_ems, vnic_profile_id)
    end
  end

  def check_task!(t, msg)
    raise msg if t.nil? || MiqTask.status_error?(t.status) || MiqTask.status_timeout?(t.status)
  end

  def submit_import_vm(userid, source_vm_id, target_params)
    task_id = queue_self_method_call(userid, 'Import VM', 'import_vm', source_vm_id, target_params)
    task = MiqTask.wait_for_taskid(task_id)

    check_task!(task, _('Error while importing the VM.'))

    task.task_results
  end

  def validate_import_vm
    # The version of the RHV needs to be at least 4.1.5 due to https://bugzilla.redhat.com/1477375
    version_higher_than?('4.1.5')
  end

  def submit_configure_imported_vm_networks(userid, vm_id)
    task_id = queue_self_method_call(userid, "Configure imported VM's networks", 'configure_imported_vm_networks', vm_id)
    task = MiqTask.wait_for_taskid(task_id)

    check_task!(task, _('Error while configuring VM network.'))

    task.task_results
  end

  private

  def check_import_supported!(source_provider)
    raise _('Cannot import archived VMs') if source_provider.nil?

    raise _('Cannot import to a RHEV provider of version < 4.1.5') unless validate_import_vm
    unless source_provider.type == ManageIQ::Providers::Vmware::InfraManager.name
      raise _('Source provider must be of type Vmware')
    end
  end

  def queue_self_method_call(userid, action, method_name, *args)
    task_options = {
      :action => action,
      :userid => userid
    }

    queue_options = {
      :task_id     => nil, # run this task concurrently,
      # since this is called by an (automate) task without this the task_id would be inherited from it
      # and cause a deadlock in subsequent waiting on this task from synchronous context
      :zone        => my_zone,
      :class_name  => self.class.name,
      :method_name => method_name,
      :instance_id => id,
      :role        => 'ems_operations',
      :args        => args
    }

    _log.info("Queueing '#{method_name}' with args #{args} by user #{userid}")
    MiqTask.generic_action_with_callback(task_options, queue_options)
  end

  def perform_vmware_to_ovirt_import(params)
    with_provider_connection :version => 4 do |conn|
      import = conn.system_service.external_vm_imports_service.add(
        OvirtSDK4::ExternalVmImport.new(
          :name           => params[:source_vm_name],
          :vm             => { :name => params[:target_vm_name] || params[:source_vm_name] },
          :provider       => OvirtSDK4::ExternalVmProviderType::VMWARE,
          :username       => params[:username],
          :password       => params[:password],
          :url            => params[:url],
          :cluster        => { :id => params[:cluster_id] },
          :storage_domain => { :id => params[:storage_domain_id] },
          :sparse         => params[:sparse],
          :drivers_iso    => params[:drivers_iso].try { |iso| OvirtSDK4::File.new(:id => iso) }
        )
      )
      self.class.make_ems_ref(import.vm.href)
    end
  end

  def vmware_import_url(provider, vm)
    username = password_auth(provider).userid
    host = select_host(vm)
    cluster = vm.parent_resource_pool.absolute_path(:exclude_ems => true, :exclude_hidden => true)
    vcenter = provider.endpoints.first.hostname
    "vpx://#{escape_username(username)}@#{vcenter}/#{escape_cluster(cluster)}/#{host.ipaddress}?no_verify=1"
  end

  def escape_username(username)
    username.sub('@', '%40')
  end

  def escape_cluster(cluster)
    URI.escape cluster, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
  end

  def select_host(vm)
    vm.ems_cluster.hosts.first # any host from the VM's cluster
  end

  def password_auth(provider)
    provider.authentication_userid_passwords.first
  end

  def first_vm_network_id(conn, dc_id)
    conn.system_service.data_centers_service.data_center_service(dc_id)
        .networks_service.list.select { |net| net.usages.include? OvirtSDK4::NetworkUsage::VM }.min_by(&:name).id
  end

  def vnic_profile_id_by_network_id(conn, network_id)
    conn.system_service.networks_service.network_service(network_id).vnic_profiles_service.list.min_by(&:name).id
  end

  def set_all_vm_nics_to_profile_id(conn, vm_id, profile_id)
    vm_nics_service = conn.system_service.vms_service.vm_service(vm_id).nics_service
    vm_nics_service.list.each do |nic|
      vm_nics_service.nic_service(nic.id).update(:vnic_profile => {:id => profile_id})
    end
  end
end
