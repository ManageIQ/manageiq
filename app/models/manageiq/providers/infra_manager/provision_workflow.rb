class ManageIQ::Providers::InfraManager::ProvisionWorkflow < ::MiqProvisionVirtWorkflow
  def set_or_default_hardware_field_values(vm)
    update_values = {
      :vm_memory      => vm.hardware.memory_mb.to_s,
      :cpu_limit      => vm.cpu_limit,
      :memory_limit   => vm.memory_limit,
      :cpu_reserve    => vm.cpu_reserve,
      :memory_reserve => vm.memory_reserve
    }.merge!(get_cpu_values_hash(vm))
    set_or_default_field_values(update_values)
  end

  def get_cpu_values_hash(vm)
    {
      :number_of_cpus    => vm.hardware.cpu_total_cores,
      :number_of_sockets => vm.hardware.cpu_sockets,
      :cores_per_socket  => vm.hardware.cpu_cores_per_socket
    }
  end

  # Run the relationship methods and perform set intersections on the returned values.
  # Optional starting set of results maybe passed in.
  def allowed_ci(ci, relats, filtered_ids = nil)
    return {} if get_value(@values[:placement_auto]) == true
    return {} if (sources = resources_for_ui).blank?
    get_ems_metadata_tree(sources)
    super(ci, relats, sources, filtered_ids)
  end

  def get_source_and_targets(refresh = false)
    return @target_resource if @target_resource && refresh == false
    result = super
    return result if result.blank?

    add_target(:placement_host_name,    :host,    Host,         result)
    add_target(:placement_ds_name,      :storage, Storage,      result)
    add_target(:placement_cluster_name, :cluster, EmsCluster,   result)
    add_target(:placement_rp_name,      :respool, ResourcePool, result)
    add_target(:placement_folder_name,  :folder,  EmsFolder,    result)

    if result[:folder_id].nil?
      add_target(:placement_dc_name, :datacenter, EmsFolder, result)
    else
      result[:datacenter] = find_datacenter_for_ci(result[:folder], get_ems_metadata_tree(result))
      result[:datacenter_id] = result[:datacenter].id unless result[:datacenter].nil?
    end

    rails_logger('get_source_and_targets', 1)
    @target_resource = result
  end

  def dialog_name_from_automate(message, extra_attrs)
    extra_attrs['platform_category'] = 'infra'
    super(message, extra_attrs)
  end
end
