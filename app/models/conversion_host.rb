class ConversionHost < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true

  def active_tasks
    ServiceTemplateTransformationPlanTask.where(:state => 'active').select do |task|
      task.conversion_host == self
    end
  end

  def eligible?
    return true if concurrent_transformation_limit.nil?
    active_tasks.size < concurrent_transformation_limit.to_i
  end

  def source_transport_method
    return 'vddk' if vddk_transport_supported
    return 'ssh' if ssh_transport_supported
  end

  def conversion_options(task)
    source_vm = task.source
    source_ems = source_vm.ext_management_system
    source_cluster = source_vm.ems_cluster
    source_storage = source_vm.hardware.disks.select { |d| d.device_type == 'disk' }.first.storage

    destination_cluster = task.transformation_destination(source_cluster)
    destination_storage = task.transformation_destination(source_storage)
    destination_ems = destination_cluster.ext_management_system

    source_provider_options = send(
      "conversion_options_source_provider_#{source_ems.emstype}_#{source_transport_method}",
      source_vm,
      source_storage
    )
    destination_provider_options = send(
      "conversion_options_destination_provider_#{destination_ems.emstype}",
      task,
      destination_ems,
      destination_cluster,
      destination_storage
    )
    options = {
      :source_disks     => task.source_disks.map { |disk| disk[:path] },
      :network_mappings => task.network_mappings
    }
    options.merge(source_provider_options).merge(destination_provider_options)
  end

  def conversion_options_source_provider_vmwarews_vddk(vm, _storage)
    {
      :vm_name            => vm.name,
      :transport_method   => 'vddk',
      :vmware_fingerprint => vm.host.fingerprint,
      :vmware_uri         => URI::Generic.build(
        :scheme   => 'esx',
        :userinfo => CGI.escape(vm.host.authentication_userid),
        :host     => vm.host.ipaddress,
        :path     => '/',
        :query    => { :no_verify => 1 }.to_query
      ).to_s,
      :vmware_password    => vm.host.authentication_password
    }
  end

  def conversion_options_source_provider_vmwarews_ssh(vm, storage)
    {
      :vm_name          => URI::Generic.build(:scheme => 'ssh', :userinfo => 'root', :host => vm.host.ipaddress, :path => "/vmfs/volumes").to_s + "/#{storage.name}/#{vm.location}",
      :transport_method => 'ssh'
    }
  end

  def conversion_options_destination_provider_rhevm(_task, ems, cluster, storage)
    {
      :rhv_url             => URI::Generic.build(:scheme => 'https', :host => ems.hostname, :path => '/ovirt-engine/api').to_s,
      :rhv_cluster         => cluster.name,
      :rhv_storage         => storage.name,
      :rhv_password        => ems.authentication_password,
      :install_drivers     => true,
      :insecure_connection => true
    }
  end

  def conversion_options_destination_provider_openstack(task, ems, cluster, storage)
    {
      :osp_environment            => {
        :os_no_cache         => true,
        :os_auth_url         => URI::Generic.build(
          :scheme => ems.security_protocol == 'non-ssl' ? 'http' : 'https',
          :host   => ems.hostname,
          :port   => ems.port,
          :path   => ems.api_version
        ),
        :os_user_domain_name => ems.uid_ems,
        :os_username         => ems.authentication_userid,
        :os_password         => ems.authentication_password,
        :os_project_name     => cluster.name
      },
      :osp_destination_project_id => cluster.ems_ref,
      :osp_volume_type_id         => storage.ems_ref,
      :osp_flavor_id              => task.destination_flavor.ems_ref,
      :osp_security_groups_ids    => [task.destination_security_group.ems_ref]
    }
  end
end
