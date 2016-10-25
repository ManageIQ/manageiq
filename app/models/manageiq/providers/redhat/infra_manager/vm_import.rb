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
      :sparse            => target_params[:sparse]
    )
  end

  def validate_import_vm
    api_version >= '4.0'
  end

  private

  def check_import_supported!(source_provider)
    raise _('Cannot import archived VMs') if source_provider.nil?

    raise _('Cannot import to a RHEV provider of version < 4.0') unless api_version >= '4.0'
    unless source_provider.type == ManageIQ::Providers::Vmware::InfraManager.name
      raise _('Source provider must be of type Vmware')
    end
  end

  def perform_vmware_to_ovirt_import(params)
    with_provider_connection :version => 4 do |conn|
      conn.system_service.external_vm_imports_service.add(
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
        )
      )
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
