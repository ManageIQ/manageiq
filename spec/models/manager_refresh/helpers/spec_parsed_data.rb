require 'bigdecimal'

module SpecParsedData
  def vm_data(i, data = {})
    {
      :type            => ManageIQ::Providers::CloudManager::Vm.name,
      :ems_id          => @ems.id,
      :uid_ems         => "vm_uid_ems_#{i}",
      :ems_ref         => "vm_ems_ref_#{i}",
      :name            => "vm_name_#{i}",
      :vendor          => "amazon",
      :raw_power_state => "unknown",
      :location        => "vm_location_#{i}",
    }.merge(data)
  end

  def key_pair_data(i, data = {})
    {
      :type          => ManageIQ::Providers::CloudManager::AuthKeyPair.name,
      :resource_id   => @ems.id,
      :resource_type => "ExtManagementSystem",
      :name          => "key_pair_name_#{i}",
    }.merge(data)
  end

  def image_data(i, data = {})
    {
      :type               => ManageIQ::Providers::CloudManager::Template.name,
      :ems_id             => @ems.id,
      :uid_ems            => "image_uid_ems_#{i}",
      :ems_ref            => "image_ems_ref_#{i}",
      :name               => "image_name_#{i}",
      :location           => "image_location_#{i}",
      :vendor             => "amazon",
      :raw_power_state    => "never",
      :template           => true,
      :publicly_available => false,
    }.merge(data)
  end

  def hardware_data(i, data = {})
    {
      :bitness             => "64",
      :virtualization_type => "virtualization_type_#{i}",
    }.merge(data)
  end

  def image_hardware_data(i, data = {})
    {
      :guest_os => "linux_generic_#{i}",
    }.merge(data)
  end

  def disk_data(i, data = {})
    {
      :device_name => "disk_name_#{i}",
      :device_type => "disk",
    }.merge(data)
  end

  def public_network_data(i, data = {})
    {
      :ipaddress   => "10.10.10.#{i}",
      :hostname    => "host_10_10_10_#{i}.com",
      :description => "public"
    }.merge(data)
  end

  def flavor_data(i, data = {})
    {
      :name   => "t#{i}.nano",
      :ems_id => @ems.id,
    }.merge(data)
  end

  def orchestration_stack_data(i, data = {})
    {
      :ems_ref       => "stack_ems_ref_#{i}",
      :type          => "ManageIQ::Providers::CloudManager::OrchestrationStack",
      :ems_id        => @ems.id,
      :name          => "stack_name_#{i}",
      :description   => "stack_description_#{i}",
      :status        => "stack_status_#{i}",
      :status_reason => "stack_status_reason_#{i}",
    }.merge(data)
  end

  def orchestration_stack_resource_data(i, data = {})
    {
      :ems_ref           => "stack_resource_physical_resource_#{i}",
      :name              => "stack_resource_name_#{i}",
      :logical_resource  => "stack_resource_logical_resource_#{i}",
      :physical_resource => "stack_resource_physical_resource_#{i}",
    }.merge(data)
  end

  def network_port_data(i, data = {})
    {
      :name        => "network_port_name_#{i}",
      :ems_id      => @ems.network_manager.try(:id),
      :ems_ref     => "network_port_ems_ref_#{i}",
      :status      => "network_port_status#{i}",
      :mac_address => "network_port_mac_#{i}",
    }.merge(data)
  end

  def container_quota_items_data(i, data = {})
    {
      :quota_desired => BigDecimal("#{i}.#{i}"),
    }.merge(data)
  end

  def container_quota_items_attrs_data(i, data = {})
    {
      :name          => "container_quota_items_attrs_#{i}",
      :resource_type => "ContainerQuotaItem",
    }.merge(data)
  end

  def container_data(i, data = {})
    {
      :type                 => "ManageIQ::Providers::Kubernetes::ContainerManager::Container",
      :ems_ref              => "container_ems_ref_#{i}",
      :name                 => "container_name_#{i}",
      :image                => "example.com:1234/kubernetes/heapster:v0.16.0",
      :image_pull_policy    => "IfNotPresent",
      :command              => "/heapster --source\\=kubernetes:https://kubernetes --sink\\=influxdb:http://monitoring-influxdb:80",
      :memory               => nil,
      :cpu_cores            => 0.0,
      :capabilities_add     => "",
      :capabilities_drop    => "",
      :privileged           => nil,
      :run_as_user          => nil,
      :run_as_non_root      => nil,
      :limit_cpu_cores      => nil,
      :limit_memory_bytes   => nil,
      :request_cpu_cores    => nil,
      :request_memory_bytes => nil,
      :restart_count        => 2,
      :backing_ref          => "docker://2baa337fef20ab18c5cae16937fca0b4a59ccbb5ecac1f89ad7898a02d74e3c9",
      :last_state           => :terminated,
      :last_reason          => nil,
      :last_started_at      => nil,
      :last_finished_at     => nil,
      :last_exit_code       => nil,
      :last_signal          => nil,
      :last_message         => nil,
      :state                => :running,
      :reason               => nil,
      :started_at           => nil,
      :finished_at          => nil,
      :exit_code            => nil,
      :signal               => nil,
      :message              => nil,
    }.merge(data)
  end

  def container_group_data(i, data = {})
    {
      :ems_ref          => "container_group_ems_ref_#{i}",
      :name             => "container_group_name_#{i}",
      :ems_created_on   => "2015-07-29T13:02:52Z",
      :resource_version => 5253,
      :type             => "ManageIQ::Providers::Kubernetes::ContainerManager::ContainerGroup",
      :restart_policy   => "Always",
      :dns_policy       => "ClusterFirst",
      :ipaddress        => "172.17.0.3",
      :phase            => "Running",
      :message          => nil,
      :reason           => nil,
    }.merge(data)
  end

  def container_image_data(i, data = {})
    {
      :name      => "container_image_name_#{i}",
      :tag       => "v0.16.0",
      :digest    => "f79cf2701046bea8d5f1384f7efe79dd4d20620b3594fff5be39142fa862259d",
      :image_ref => "container_image_image_ref_#{i}",
    }.merge(data)
  end

  def container_image_registry_data(i, data = {})
    {
      :name => "container_image_registry_name_#{i}",
      :host => "container_image_registry_host_#{i}",
      :port => "1234"
    }.merge(data)
  end

  def container_project_data(i, data = {})
    {
      :ems_ref          => "container_project_ems_ref_#{i}",
      :name             => "container_project_name_#{i}",
      :ems_created_on   => "2015-07-29T12:50:33Z",
      :resource_version => 6
    }.merge(data)
  end

  def container_replicator_data(i, data = {})
    {
      :ems_ref          => "container_replicator_ems_ref_#{i}",
      :name             => "container_replicator_name_#{i}",
      :ems_created_on   => "2015-07-29T13:02:52Z",
      :resource_version => 122,
      :replicas         => 1,
      :current_replicas => 1,
    }.merge(data)
  end

  def container_node_data(i, data = {})
    {
      :ems_ref                    => "container_node_ems_ref_#{i}",
      :name                       => "container_node_name_#{i}",
      :ems_created_on             => "2015-07-29T12:50:45Z",
      :resource_version           => 5302,
      :type                       => "ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode",
      :identity_infra             => nil,
      :lives_on_id                => 18882,
      :lives_on_type              => "ManageIQ::Providers::Openstack::CloudManager::Vm",
      :identity_machine           => "8b6c70709abd41aca950e4cfac665673",
      :identity_system            => "8B6C7070-9ABD-41AC-A950-E4CFAC665673",
      :container_runtime_version  => "docker://1.5.0",
      :kubernetes_proxy_version   => "v1.0.0-dirty",
      :kubernetes_kubelet_version => "v1.0.0-dirty",
      :max_container_groups       => 40
    }.merge(data)
  end
end
