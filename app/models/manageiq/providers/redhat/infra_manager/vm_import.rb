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
      :drivers_iso       => target_params[:drivers_iso]
    )
  end

  def submit_import_vm(userid, source_vm_id, target_params)
    task_id = queue_import_vm(userid, source_vm_id, target_params)
    task = MiqTask.wait_for_taskid(task_id)

    task.task_results
  end

  def validate_import_vm
    highest_supported_api_version && highest_supported_api_version >= '4'
  end

  private

  def check_import_supported!(source_provider)
    raise _('Cannot import archived VMs') if source_provider.nil?

    raise _('Cannot import to a RHEV provider of version < 4.0') unless api_version >= '4.0'
    unless source_provider.type == ManageIQ::Providers::Vmware::InfraManager.name
      raise _('Source provider must be of type Vmware')
    end
  end

  def queue_import_vm(userid, source_vm_id, target_params)
    task_options = {
      :action => 'Import VM',
      :userid => userid
    }

    queue_options = {
      :task_id     => nil, # run this task concurrently,
      # since this is called by an (automate) task without this the task_id would be inherited from it
      # and cause a deadlock in subsequent waiting on this task from synchronous context
      :zone        => my_zone,
      :class_name  => self.class.name,
      :method_name => 'import_vm',
      :instance_id => id,
      :role        => 'ems_operations',
      :args        => [source_vm_id, target_params]
    }

    _log.info("Queueing import of VM ID: #{source_vm_id} by user #{userid}")
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
end
