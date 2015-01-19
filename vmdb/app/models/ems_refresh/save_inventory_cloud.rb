#
# Calling order for EmsCloud
# - ems
#   - flavors
#   - availability_zones
#   - cloud_tenants
#   - key_pairs
#   - orchestration_templates
#   - orchestration_stacks
#   - cloud_networks
#     - cloud_subnets
#   - security_groups
#     - firewall_rules
#   - cloud_volumes
#   - cloud_volume_snapshots
#   - vms
#     - storages (link)
#     - security_groups (link)
#     - operating_system
#     - hardware
#       - disks
#       - guest_devices
#     - custom_attributes
#     - snapshots
#   - floating_ips
#   - cloud_object_store_containers
#     - cloud_object_store_objects
#

module EmsRefresh::SaveInventoryCloud
  def save_ems_cloud_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "MIQ(#{self.name}.save_ems_cloud_inventory) EMS: [#{ems.name}], id: [#{ems.id}]"

    # Check if the data coming in reflects a complete removal from the ems
    if hashes.blank?
      target.disconnect_inv
      return
    end

    $log.info("#{log_header} Saving EMS Inventory...")
    if debug_trace
      require 'yaml'
      $log.debug "#{log_header} hashes:\n#{YAML.dump(hashes)}"
    end

    child_keys = [
      :flavors,
      :availability_zones,
      :cloud_tenants,
      :key_pairs,
      :orchestration_templates,
      :orchestration_stacks,
      :cloud_networks,
      :security_groups,
      :cloud_volumes,
      :cloud_volume_snapshots,
      :vms,
      :floating_ips,
      :cloud_resource_quotas,
      :cloud_object_store_containers,
      :cloud_object_store_objects
    ]

    # Save and link other subsections
    save_child_inventory(ems, hashes, child_keys, target)

    link_volumes_to_base_snapshots(hashes[:cloud_volumes]) if hashes.key?(:cloud_volumes)

    ems.save!
    hashes[:id] = ems.id

    $log.info("#{log_header} Saving EMS Inventory...Complete")

    return ems
  end

  def save_flavors_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.flavors(true)
    deletes = if (target == ems)
      ems.flavors.dup
    else
      []
    end

    save_inventory_multi(:flavors, ems, hashes, deletes, :ems_ref)
    self.store_ids_for_new_records(ems.flavors, hashes, :ems_ref)
  end

  def save_availability_zones_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.availability_zones(true)
    deletes = if (target == ems)
      ems.availability_zones.dup
    else
      []
    end

    save_inventory_multi(:availability_zones, ems, hashes, deletes, :ems_ref)
    self.store_ids_for_new_records(ems.availability_zones, hashes, :ems_ref)
  end

  def save_cloud_tenants_inventory(ems, hashes, target = nil)
    target ||= ems

    ems.cloud_tenants(true)
    deletes = if (target == ems)
      ems.cloud_tenants.dup
    else
      []
    end

    save_inventory_multi(:cloud_tenants, ems, hashes, deletes, :ems_ref)
    self.store_ids_for_new_records(ems.cloud_tenants, hashes, :ems_ref)
  end

  def save_cloud_resource_quotas_inventory(ems, hashes, target = nil)
    target ||= ems

    ems.cloud_resource_quotas(true)
    deletes = if (target == ems)
      ems.cloud_resource_quotas.dup
    else
      []
    end

    hashes.each do |h|
      h[:cloud_tenant_id] = h.fetch_path(:cloud_tenant, :id)
    end

    save_inventory_multi(:cloud_resource_quotas, ems, hashes, deletes, [:ems_ref, :name], nil, :cloud_tenant)
    self.store_ids_for_new_records(ems.cloud_resource_quotas, hashes, [:ems_ref, :name])
  end

  def save_key_pairs_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.key_pairs(true)
    deletes = if (target == ems)
      ems.key_pairs.dup
    else
      []
    end

    save_inventory_multi(:key_pairs, ems, hashes, deletes, :name)
    self.store_ids_for_new_records(ems.key_pairs, hashes, :name)
  end


  def save_cloud_networks_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_networks(true)
    deletes = if (target == ems)
      ems.cloud_networks.dup
    else
      []
    end

    hashes.each do |h|
      h[:cloud_tenant_id]        = h.fetch_path(:cloud_tenant, :id)
      h[:orchestration_stack_id] = h.fetch_path(:orchestration_stack, :id)
    end

    save_inventory_multi(:cloud_networks,
                         ems,
                         hashes,
                         deletes,
                         :ems_ref,
                         :cloud_subnets,
                         [:cloud_tenant, :orchestration_stack])
    store_ids_for_new_records(ems.cloud_networks, hashes, :ems_ref)
  end

  def save_cloud_subnets_inventory(cloud_network, hashes)
    deletes = cloud_network.cloud_subnets(true).dup

    hashes.each do |h|
      h[:availability_zone_id] = h.fetch_path(:availability_zone, :id)
    end

    save_inventory_multi(:cloud_subnets, cloud_network, hashes, deletes, :ems_ref, nil, :availability_zone)

    cloud_network.save!
    self.store_ids_for_new_records(cloud_network.cloud_subnets, hashes, :ems_ref)
  end

  def save_security_groups_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.security_groups(true)
    deletes = if (target == ems)
      ems.security_groups.dup
    else
      []
    end

    hashes.each do |h|
      h[:cloud_network_id]       = h.fetch_path(:cloud_network, :id)
      h[:cloud_tenant_id]        = h.fetch_path(:cloud_tenant, :id)
      h[:orchestration_stack_id] = h.fetch_path(:orchestration_stack, :id)
    end

    save_inventory_multi(:security_groups,
                         ems, hashes,
                         deletes,
                         :ems_ref,
                         :firewall_rules,
                         [:cloud_network, :cloud_tenant, :orchestration_stack])
    store_ids_for_new_records(ems.security_groups, hashes, :ems_ref)

    # Reset the source_security_group_id for the firewall rules after all
    #   security groups have been saved and ids obtained.
    firewall_rule_hashes = hashes.collect { |h| h[:firewall_rules] }.flatten.index_by { |h| h[:id] }
    firewall_rules       = ems.security_groups.collect(&:firewall_rules).flatten
    firewall_rules.each do |fr|
      fr_hash = firewall_rule_hashes[fr.id]
      fr_hash[:source_security_group_id] = fr_hash.fetch_path(:source_security_group, :id)
      fr.update_attribute(:source_security_group_id, fr_hash[:source_security_group_id])
    end
  end

  def save_floating_ips_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.floating_ips(true)
    deletes = if (target == ems)
      ems.floating_ips.dup
    else
      []
    end

    hashes.each do |h|
      h[:vm_id] = h.fetch_path(:vm, :id)
      # floating ip tenants are not supported with nova network
      h[:cloud_tenant_id] = h.fetch_path(:cloud_tenant, :id) if h.key?(:cloud_tenant)
    end

    save_inventory_multi(:floating_ips, ems, hashes, deletes, :ems_ref, nil, [:vm, :cloud_tenant])
    self.store_ids_for_new_records(ems.floating_ips, hashes, :ems_ref)
  end

  def save_orchestration_templates_inventory(_ems, hashes, _target = nil)
    # cloud_stack_template does not belong to an ems;
    # only to create new if necessary, but not to update existing template
    templates = OrchestrationTemplate.find_or_create_by_contents(hashes)
    hashes.zip(templates).each { |hash, template| hash[:id] = template.id }
  end

  def save_orchestration_stacks_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.orchestration_stacks(true)
    deletes = if (target == ems)
      ems.orchestration_stacks.dup
    else
      []
    end

    hashes.each do |h|
      h[:orchestration_template_id] = h.fetch_path(:orchestration_template, :id)
    end

    stacks = save_inventory_multi(:orchestration_stacks,
                                  ems,
                                  hashes,
                                  deletes,
                                  :ems_ref,
                                  [:parameters, :outputs, :resources],
                                  [:parent, :orchestration_template])
    store_ids_for_new_records(ems.orchestration_stacks, hashes, :ems_ref)

    save_orchestration_stack_nesting(stacks.index_by(&:id), hashes)
  end

  def save_orchestration_stack_nesting(stacks, hashes)
    hashes.each do |hash|
      next unless hash[:parent]
      stacks[hash[:id]].update_attribute(:parent_id, hash[:parent][:id])
    end
  end

  def save_parameters_inventory(orchestration_stack, hashes)
    deletes = orchestration_stack.parameters(true).dup

    save_inventory_multi(:parameters,
                         orchestration_stack,
                         hashes,
                         deletes,
                         :ems_ref)
  end

  def save_outputs_inventory(orchestration_stack, hashes)
    deletes = orchestration_stack.outputs(true).dup

    save_inventory_multi(:outputs,
                         orchestration_stack,
                         hashes,
                         deletes,
                         :ems_ref)
  end

  def save_resources_inventory(orchestration_stack, hashes)
    deletes = orchestration_stack.resources(true).dup

    save_inventory_multi(:resources,
                         orchestration_stack,
                         hashes,
                         deletes,
                         :ems_ref)
  end

  def save_cloud_volumes_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_volumes(true)
    deletes = if (target == ems)
      ems.cloud_volumes.dup
    else
      []
    end

    hashes.each do |h|
      h[:ems_id]               = ems.id
      h[:cloud_tenant_id]      = h.fetch_path(:tenant, :id)
      h[:availability_zone_id] = h.fetch_path(:availability_zone, :id)
      # Defer setting :cloud_volume_snapshot_id until after snapshots are saved.
    end

    save_inventory_multi(:cloud_volumes, ems, hashes, deletes, :ems_ref, nil, [:tenant, :availability_zone, :base_snapshot])
    self.store_ids_for_new_records(ems.cloud_volumes, hashes, :ems_ref)
  end

  def save_cloud_volume_snapshots_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_volume_snapshots(true)
    deletes = if (target == ems)
      ems.cloud_volume_snapshots.dup
    else
      []
    end

    hashes.each do |h|
      h[:ems_id]          = ems.id
      h[:cloud_tenant_id] = h.fetch_path(:tenant, :id)
      h[:cloud_volume_id] = h.fetch_path(:volume, :id)
    end

    save_inventory_multi(:cloud_volume_snapshots, ems, hashes, deletes, :ems_ref, nil, [:tenant, :volume])
    self.store_ids_for_new_records(ems.cloud_volume_snapshots, hashes, :ems_ref)
  end

  def link_volumes_to_base_snapshots(hashes)
    base_snapshot_to_volume = hashes.each_with_object({}) do |h, bsh|
      next unless (base_snapshot = h[:base_snapshot])
      (bsh[base_snapshot[:id]] ||= []) << h[:id]
    end

    base_snapshot_to_volume.each do |bsid, volids|
      CloudVolume.update_all({:cloud_volume_snapshot_id => bsid}, {:id => volids})
    end
  end

  def save_cloud_object_store_containers_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_object_store_containers(true)
    deletes = if (target == ems)
      ems.cloud_object_store_containers.dup
    else
      []
    end

    hashes.each do |h|
      h[:ems_id]          = ems.id
      h[:cloud_tenant_id] = h.fetch_path(:tenant, :id)
    end

    save_inventory_multi(:cloud_object_store_containers, ems, hashes, deletes, :ems_ref, nil, :tenant)
    self.store_ids_for_new_records(ems.cloud_object_store_containers, hashes, :ems_ref)
  end

  def save_cloud_object_store_objects_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_object_store_objects(true)
    deletes = if (target == ems)
      ems.cloud_object_store_objects.dup
    else
      []
    end

    hashes.each do |h|
      h[:ems_id]                          = ems.id
      h[:cloud_tenant_id]                 = h.fetch_path(:tenant, :id)
      h[:cloud_object_store_container_id] = h.fetch_path(:container, :id)
    end

    save_inventory_multi(:cloud_object_store_objects, ems, hashes, deletes, :ems_ref, nil, [:tenant, :container])
    self.store_ids_for_new_records(ems.cloud_object_store_objects, hashes, :ems_ref)
  end
end
