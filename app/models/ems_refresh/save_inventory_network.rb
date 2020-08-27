module EmsRefresh::SaveInventoryNetwork
  def save_cloud_networks_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_networks.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    save_inventory_multi(ems.cloud_networks,
                         hashes,
                         deletes,
                         [:ems_ref],
                         :cloud_subnets)
    store_ids_for_new_records(ems.cloud_networks, hashes, :ems_ref)
  end

  def save_network_groups_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.network_groups.reload
    deletes = if target == ems
                ems.network_groups.dup
              else
                []
              end

    save_inventory_multi(ems.network_groups,
                         hashes,
                         deletes,
                         [:ems_ref],
                         :cloud_subnets,
                         [:orchestration_stack])
    store_ids_for_new_records(ems.network_groups, hashes, :ems_ref)
  end

  def save_cloud_subnets_inventory(network, hashes, _target = nil)
    hashes.each do |h|
      h[:cloud_network_id] = h.fetch_path(:cloud_network, :id) if h.key?(:cloud_network)

      h[:ems_id] = network.ems_id if network.respond_to?(:ems_id)
    end

    save_inventory_multi(network.cloud_subnets, hashes, :use_association, [:ems_ref], nil, [:network_router, :cloud_network])

    network.save! unless network.kind_of?(ManageIQ::Providers::NetworkManager)
    store_ids_for_new_records(network.cloud_subnets, hashes, :ems_ref)
  end

  def save_security_groups_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.security_groups.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:cloud_network_id] = h.fetch_path(:cloud_network, :id)
      h[:network_group_id] = h.fetch_path(:network_group, :id)
    end

    save_inventory_multi(ems.security_groups,
                         hashes,
                         deletes,
                         [:ems_ref],
                         :firewall_rules,
                         [:cloud_network, :network_group])
    store_ids_for_new_records(ems.security_groups, hashes, :ems_ref)

    # Reset the source_security_group_id for the firewall rules after all
    #   security groups have been saved and ids obtained.
    firewall_rule_hashes = hashes.collect { |h| h[:firewall_rules] }.flatten.compact.index_by { |h| h[:id] }
    firewall_rules       = ems.security_groups.collect(&:firewall_rules).flatten
    firewall_rules.each do |fr|
      fr_hash = firewall_rule_hashes[fr.id] || {}
      fr_hash[:source_security_group_id] = fr_hash.fetch_path(:source_security_group, :id)
      fr.update_attribute(:source_security_group_id, fr_hash[:source_security_group_id])
    end
  end

  def save_floating_ips_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.floating_ips.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:cloud_network_id] = h.fetch_path(:cloud_network, :id)
      h[:network_port_id]  = h.fetch_path(:network_port, :id)
    end

    save_inventory_multi(ems.floating_ips, hashes, deletes, [:ems_ref], nil, [:cloud_network, :network_port])
    store_ids_for_new_records(ems.floating_ips, hashes, :ems_ref)
  end

  def save_firewall_rules_inventory(parent, hashes, mode = :refresh)
    return if hashes.nil?

    find_key =
      case mode
      when :refresh
        # Leaves out the source_security_group_id, as we will set that later
        #   after all security_groups have been saved and ids obtained.
        if parent.kind_of?(ManageIQ::Providers::Openstack::NetworkManager::SecurityGroup)
          [:ems_ref]
        else
          [:direction, :host_protocol, :port, :end_port, :source_ip_range]
        end
      when :scan
        [:name]
      end

    save_inventory_multi(parent.firewall_rules, hashes, :use_association, find_key, nil, [:source_security_group])

    parent.save!
    store_ids_for_new_records(parent.firewall_rules, hashes, find_key)
  end

  def save_network_routers_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.network_routers.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:cloud_network_id] = h.fetch_path(:cloud_network, :id)
      h[:network_group_id] = h.fetch_path(:network_group, :id)
    end

    save_inventory_multi(ems.network_routers,
                         hashes,
                         deletes,
                         [:ems_ref],
                         nil,
                         [:cloud_network, :network_group])
    store_ids_for_new_records(ems.network_routers, hashes, :ems_ref)
  end

  def save_load_balancers_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.load_balancers.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    save_inventory_multi(ems.load_balancers, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(ems.load_balancers, hashes, :ems_ref)
  end

  def save_network_ports_inventory(ems, hashes, target = nil, mode = :refresh)
    target = ems if target.nil?

    ems.network_ports.reset
    deletes = if target == ems
                ems.network_ports.where(:source => mode).dup
              else
                []
              end

    # Remove non valid ports stored as nil
    hashes.compact!

    hashes.each do |h|
      device = h.fetch_path(:device)
      if device.kind_of?(Hash)
        h.delete(:device)

        h[:device_id]   = device[:id]
        h[:device_type] = device[:type].constantize.base_class.name
      end

      h[:security_group_ids] = (h.delete(:security_groups) || []).map { |x| x.try(:[], :id) }.compact.uniq
      h[:source] = mode
    end

    save_inventory_multi(ems.network_ports,
                         hashes,
                         deletes,
                         [:ems_ref],
                         :cloud_subnet_network_ports,
                         [:cloud_subnet])

    store_ids_for_new_records(ems.network_ports, hashes, :ems_ref)
  end

  def save_cloud_subnet_network_ports_inventory(network_port, hashes)
    deletes = network_port.cloud_subnet_network_ports.reload.dup

    hashes.each do |h|
      h[:cloud_subnet_id] = h.fetch_path(:cloud_subnet, :id)
    end

    save_inventory_multi(network_port.cloud_subnet_network_ports,
                         hashes,
                         deletes,
                         [:cloud_subnet_id, :address],
                         nil,
                         [:cloud_subnet])
  end

  def save_load_balancer_pool_members_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.load_balancer_pool_members.reload
    deletes = if target == ems
                ems.load_balancer_pool_members.dup
              else
                []
              end

    save_inventory_multi(ems.load_balancer_pool_members,
                         hashes,
                         deletes,
                         [:ems_ref])
    store_ids_for_new_records(ems.load_balancer_pool_members, hashes, :ems_ref)
  end

  def save_load_balancer_pools_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.load_balancer_pools.reload
    deletes = if target == ems
                ems.load_balancer_pools.dup
              else
                []
              end

    save_inventory_multi(ems.load_balancer_pools,
                         hashes,
                         deletes,
                         [:ems_ref],
                         :load_balancer_pool_member_pools)
    store_ids_for_new_records(ems.load_balancer_pools, hashes, :ems_ref)
  end

  def save_load_balancer_pool_member_pools_inventory(load_balancer_pool, hashes)
    deletes = load_balancer_pool.load_balancer_pool_member_pools.reload.dup

    hashes.each do |h|
      h[:load_balancer_pool_member_id] = h.fetch_path(:load_balancer_pool_member, :id)
    end

    save_inventory_multi(load_balancer_pool.load_balancer_pool_member_pools,
                         hashes, deletes,
                         [:load_balancer_pool_member_id],
                         nil,
                         [:load_balancer_pool_member])
  end

  def save_load_balancer_listeners_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.load_balancer_listeners.reload
    deletes = if target == ems
                ems.load_balancer_listeners.dup
              else
                []
              end

    hashes.each do |h|
      h[:load_balancer_id] = h.fetch_path(:load_balancer, :id)
    end

    save_inventory_multi(ems.load_balancer_listeners,
                         hashes,
                         deletes,
                         [:ems_ref],
                         :load_balancer_listener_pools,
                         [:load_balancer])
    store_ids_for_new_records(ems.load_balancer_listeners, hashes, :ems_ref)
  end

  def save_load_balancer_listener_pools_inventory(load_balancer_listener, hashes)
    deletes = load_balancer_listener.load_balancer_listener_pools.reload.dup

    hashes.each do |h|
      h[:load_balancer_pool_id] = h.fetch_path(:load_balancer_pool, :id)
    end

    save_inventory_multi(load_balancer_listener.load_balancer_listener_pools,
                         hashes,
                         deletes,
                         [:load_balancer_pool_id],
                         nil,
                         [:load_balancer_pool])
  end

  def save_load_balancer_health_checks_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.load_balancer_health_checks.reload
    deletes = if target == ems
                ems.load_balancer_health_checks.dup
              else
                []
              end

    hashes.each do |h|
      h[:load_balancer_id] = h.fetch_path(:load_balancer, :id)
      h[:load_balancer_listener_id] = h.fetch_path(:load_balancer_listener, :id)
    end

    save_inventory_multi(ems.load_balancer_health_checks,
                         hashes,
                         deletes,
                         [:ems_ref],
                         :load_balancer_health_check_members,
                         [:load_balancer, :load_balancer_listener])
    store_ids_for_new_records(ems.load_balancer_health_checks, hashes, :ems_ref)
  end

  def save_load_balancer_health_check_members_inventory(load_balancer_health_check, hashes)
    deletes = load_balancer_health_check.load_balancer_health_check_members.reload.dup

    hashes.each do |h|
      h[:load_balancer_pool_member_id] = h.fetch_path(:load_balancer_pool_member, :id)
    end

    save_inventory_multi(load_balancer_health_check.load_balancer_health_check_members,
                         hashes,
                         deletes,
                         [:load_balancer_pool_member_id],
                         nil,
                         [:load_balancer_pool_member])
  end

  def link_cloud_subnets_to_network_routers(hashes)
    return if hashes.blank?

    hashes.each do |hash|
      CloudSubnet.where(:id => hash[:id]).update_all(:network_router_id => hash.fetch_path(:network_router, :id))
    end
  end
end
