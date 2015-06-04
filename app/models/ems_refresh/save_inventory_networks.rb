#
# Module for saving networks related inventory
# - networks
# - subnets
# - security groups
# - firewall rules
# - floating ips

module EmsRefresh
  module SaveInventoryNetworks
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
                           [:ems_ref],
                           :cloud_subnets,
                           [:cloud_tenant, :orchestration_stack])
      store_ids_for_new_records(ems.cloud_networks, hashes, :ems_ref)
    end

    def save_cloud_subnets_inventory(cloud_network, hashes)
      deletes = cloud_network.cloud_subnets(true).dup

      hashes.each do |h|
        h[:availability_zone_id] = h.fetch_path(:availability_zone, :id)
      end

      save_inventory_multi(:cloud_subnets, cloud_network, hashes, deletes, [:ems_ref], nil, :availability_zone)

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
                           [:ems_ref],
                           :firewall_rules,
                           [:cloud_network, :cloud_tenant, :orchestration_stack])
      store_ids_for_new_records(ems.security_groups, hashes, :ems_ref)

      # Reset the source_security_group_id for the firewall rules after all
      #   security groups have been saved and ids obtained.
      firewall_rule_hashes = hashes.collect { |h| h[:firewall_rules] }.flatten.index_by { |h| h[:id] }
      firewall_rules       = ems.security_groups.collect(&:firewall_rules).flatten
      firewall_rules.each do |fr|
        fr_hash = firewall_rule_hashes[fr.id] || {}
        fr_hash[:source_security_group_id] = fr_hash.fetch_path(:source_security_group, :id)
        fr.update_attribute(:source_security_group_id, fr_hash[:source_security_group_id])
      end
    end

    def save_firewall_rules_inventory(parent, hashes, mode = :refresh)
      return if hashes.nil?

      find_key =
        case mode
        when :refresh
          # Leaves out the source_security_group_id, as we will set that later
          #   after all security_groups have been saved and ids obtained.
          if parent.kind_of?(SecurityGroupOpenstack) || parent.kind_of?(SecurityGroupOpenstackInfra)
            [:ems_ref]
          else
            [:direction, :host_protocol, :port, :end_port, :source_ip_range]
          end
        when :scan
          [:name]
        end

      deletes = parent.firewall_rules(true).dup
      save_inventory_multi(:firewall_rules, parent, hashes, deletes, find_key, nil, [:source_security_group])

      parent.save!
      self.store_ids_for_new_records(parent.firewall_rules, hashes, find_key)
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

      save_inventory_multi(:floating_ips, ems, hashes, deletes, [:ems_ref], nil, [:vm, :cloud_tenant])
      self.store_ids_for_new_records(ems.floating_ips, hashes, :ems_ref)
    end
  end
end
