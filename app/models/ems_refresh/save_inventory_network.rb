#
# Calling order for EmsCloud
# - ems
#   - cloud_networks
#     - cloud_subnets
#   - security_groups
#     - firewall_rules
#   - load_balancers
#   - network_ports
#   - floating_ips
#   - network_routers
#   - load_balancer_pool_members
#   - load_balancer_pools
#     - load_balancer_pool_member_pools
#   - load_balancer_listeners
#     - load_balancer_listener_pools
#   - load_balancer_health_checks
#     - load_balancer_health_check_members
#

module EmsRefresh::SaveInventoryNetwork
  def save_ems_network_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    # Check if the data coming in reflects a complete removal from the ems
    if hashes.blank?
      target.disconnect_inv
      return
    end

    _log.info("#{log_header} Saving EMS Network Inventory...")
    if debug_trace
      require 'yaml'
      _log.debug "#{log_header} hashes:\n#{YAML.dump(hashes)}"
    end

    child_keys = [
      :cloud_networks,
      :cloud_subnets,
      :network_groups,
      :security_groups,
      :network_routers,
      :load_balancers,
      :network_ports,
      :floating_ips,
      :load_balancer_pool_members,
      :load_balancer_pools,
      :load_balancer_listeners,
      :load_balancer_health_checks,
    ]

    # Save and link other subsections
    save_child_inventory(ems, hashes, child_keys, target)

    link_cloud_subnets_to_network_routers(hashes[:cloud_networks].collect { |x| x[:cloud_subnets] }.flatten) if hashes.key?(:network_routers)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Network Inventory...Complete")

    ems
  end

  def save_cloud_networks_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_networks.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    hashes.each do |h|
      %i(cloud_tenant orchestration_stack).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
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

    ems.network_groups(true)
    deletes = if target == ems
                ems.network_groups.dup
              else
                []
              end

    hashes.each do |h|
      h[:orchestration_stack_id] = h.fetch_path(:orchestration_stack, :id)
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
      %i(availability_zone parent_cloud_subnet cloud_network).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end

      h[:ems_id] = network.ems_id if network.respond_to?(:ems_id)
    end

    save_inventory_multi(network.cloud_subnets, hashes, :use_association, [:ems_ref], nil, [:network_router])

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
      %i(cloud_tenant cloud_network orchestration_stack network_group).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(ems.security_groups, hashes,
                         deletes,
                         [:ems_ref],
                         :firewall_rules)
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
      %i(vm cloud_tenant cloud_network network_port).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(ems.floating_ips, hashes, deletes, [:ems_ref])
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
      %i(cloud_tenant cloud_network network_group).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(ems.network_routers,
                         hashes,
                         deletes,
                         [:ems_ref])
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

  def save_network_ports_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.network_ports.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    # Remove non valid ports stored as nil
    hashes.compact!

    hashes.each do |h|
      %i(cloud_tenant device cloud_subnet).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end

      h[:security_groups] = (h.fetch_path(:security_groups) || []).map { |x| x.try(:[], :_object) }.compact.uniq
    end

    save_inventory_multi(ems.network_ports, hashes, deletes, [:ems_ref], :cloud_subnet_network_ports)

    store_ids_for_new_records(ems.network_ports, hashes, :ems_ref)
  end

  def save_cloud_subnet_network_ports_inventory(network_port, hashes)
    deletes = network_port.cloud_subnet_network_ports.reload.dup

    hashes.each do |h|
      %i(cloud_subnet).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(network_port.cloud_subnet_network_ports, hashes, deletes, [:cloud_subnet_id, :address])
  end

  def save_load_balancer_pool_members_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.load_balancer_pool_members(true)
    deletes = if target == ems
                ems.load_balancer_pool_members.dup
              else
                []
              end

    hashes.each do |h|
      %i(vm).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(ems.load_balancer_pool_members,
                         hashes,
                         deletes,
                         [:ems_ref])
    store_ids_for_new_records(ems.load_balancer_pool_members, hashes, :ems_ref)
  end

  def save_load_balancer_pools_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.load_balancer_pools(true)
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
      %i(load_balancer_pool_member).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(load_balancer_pool.load_balancer_pool_member_pools, hashes, deletes,
                         [:load_balancer_pool_member_id])
  end

  def save_load_balancer_listeners_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.load_balancer_listeners(true)
    deletes = if target == ems
                ems.load_balancer_listeners.dup
              else
                []
              end

    hashes.each do |h|
      %i(load_balancer).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(ems.load_balancer_listeners,
                         hashes,
                         deletes,
                         [:ems_ref],
                         :load_balancer_listener_pools)
    store_ids_for_new_records(ems.load_balancer_listeners, hashes, :ems_ref)
  end

  def save_load_balancer_listener_pools_inventory(load_balancer_listener, hashes)
    deletes = load_balancer_listener.load_balancer_listener_pools.reload.dup

    hashes.each do |h|
      %i(load_balancer_pool).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(load_balancer_listener.load_balancer_listener_pools, hashes, deletes, [:load_balancer_pool_id])
  end

  def save_load_balancer_health_checks_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.load_balancer_health_checks(true)
    deletes = if target == ems
                ems.load_balancer_health_checks.dup
              else
                []
              end

    hashes.each do |h|
      %i(load_balancer load_balancer_listener).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(ems.load_balancer_health_checks,
                         hashes,
                         deletes,
                         [:ems_ref],
                         :load_balancer_health_check_members)
    store_ids_for_new_records(ems.load_balancer_health_checks, hashes, :ems_ref)
  end

  def save_load_balancer_health_check_members_inventory(load_balancer_health_check, hashes)
    deletes = load_balancer_health_check.load_balancer_health_check_members.reload.dup

    hashes.each do |h|
      %i(load_balancer_pool_member).each do |relation|
        h[relation] = h.fetch_path(relation, :_object) if h.fetch_path(relation, :_object)
      end
    end

    save_inventory_multi(load_balancer_health_check.load_balancer_health_check_members, hashes, deletes,
                         [:load_balancer_pool_member_id])
  end

  def link_cloud_subnets_to_network_routers(hashes)
    return if hashes.blank?

    hashes.each do |hash|
      network_router = hash.fetch_path(:network_router, :_object)
      hash[:_object].update_attributes(:network_router => network_router)
    end
  end
end
