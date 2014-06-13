#
# Calling order for EmsCloud
# - ems
#   - flavors
#   - availability_zones
#   - cloud_tenants
#   - key_pairs
#   - cloud_networks
#     - cloud_subnets
#   - security_groups
#     - firewall_rules
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

    child_keys = [:flavors, :availability_zones, :cloud_tenants, :key_pairs, :cloud_networks, :security_groups, :vms, :floating_ips]

    # Save and link other subsections
    child_keys.each do |k|
      self.send("save_#{k}_inventory", ems, hashes[k], target)
    end

    ems.save!
    hashes[:id] = ems.id

    $log.info("#{log_header} Saving EMS Inventory...Complete")

    return ems
  end

  def save_flavors_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.flavors(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.flavors.dup
    else
      []
    end

    self.save_inventory_multi(:flavors, Flavor, ems, hashes, deletes, :ems_ref)
    self.store_ids_for_new_records(ems.flavors, hashes, :ems_ref)
  end

  def save_availability_zones_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.availability_zones(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.availability_zones.dup
    else
      []
    end

    self.save_inventory_multi(:availability_zones, AvailabilityZone, ems, hashes, deletes, :ems_ref)
    self.store_ids_for_new_records(ems.availability_zones, hashes, :ems_ref)
  end

  def save_cloud_tenants_inventory(ems, hashes, target = nil)
    return unless hashes
    target ||= ems

    ems.cloud_tenants(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.cloud_tenants.dup
    else
      []
    end

    self.save_inventory_multi(:cloud_tenants, CloudTenant, ems, hashes, deletes, :ems_ref)
    self.store_ids_for_new_records(ems.cloud_tenants, hashes, :ems_ref)
  end

  def save_key_pairs_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.key_pairs(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.key_pairs.dup
    else
      []
    end

    self.save_inventory_multi(:key_pairs, AuthPrivateKey, ems, hashes, deletes, :name)
    self.store_ids_for_new_records(ems.key_pairs, hashes, :name)
  end


  def save_cloud_networks_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.cloud_networks(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.cloud_networks.dup
    else
      []
    end

    hashes.each do |h|
      h[:cloud_tenant_id] = h.fetch_path(:cloud_tenant, :id)
    end

    self.save_inventory_multi(:cloud_networks, CloudNetwork, ems, hashes, deletes, :ems_ref, :cloud_subnets, :cloud_tenant)
    self.store_ids_for_new_records(ems.cloud_networks, hashes, :ems_ref)
  end

  def save_cloud_subnets_inventory(cloud_network, hashes)
    return if hashes.nil?
    deletes = cloud_network.cloud_subnets(true).dup

    hashes.each do |h|
      h[:availability_zone_id] = h.fetch_path(:availability_zone, :id)
    end

    self.save_inventory_multi(:cloud_subnets, CloudSubnet, cloud_network, hashes, deletes, :ems_ref, nil, :availability_zone)

    cloud_network.save!
    self.store_ids_for_new_records(cloud_network.cloud_subnets, hashes, :ems_ref)
  end

  def save_security_groups_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.security_groups(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.security_groups.dup
    else
      []
    end

    hashes.each do |h|
      h[:cloud_network_id] = h.fetch_path(:cloud_network, :id)
      h[:cloud_tenant_id]  = h.fetch_path(:cloud_tenant, :id)
    end

    self.save_inventory_multi(:security_groups, SecurityGroup, ems, hashes, deletes, :ems_ref, :firewall_rules, [:cloud_network, :cloud_tenant])
    self.store_ids_for_new_records(ems.security_groups, hashes, :ems_ref)

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
    return if hashes.nil?
    target = ems if target.nil?

    ems.floating_ips(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.floating_ips.dup
    else
      []
    end

    hashes.each do |h|
      h[:vm_id] = h.fetch_path(:vm, :id)
      # floating ip tenants are not supported with nova network
      h[:cloud_tenant_id] = h.fetch_path(:cloud_tenant, :id) if h.key?(:cloud_tenant)
    end

    self.save_inventory_multi(:floating_ips, FloatingIp, ems, hashes, deletes, :ems_ref, nil, [:vm, :cloud_tenant])
    self.store_ids_for_new_records(ems.floating_ips, hashes, :ems_ref)
  end
end
