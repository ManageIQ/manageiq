class OpenstackResourceQuota < CloudResourceQuota
  private

  # quota_used methods defined for each known quota type
  # if no method is provided for a quota type, then -1 is returned by
  # method_missing (see parent)

  def cores_quota_used
    Hardware.joins(:vm).where(:vms => {:cloud_tenant_id => cloud_tenant_id, :power_state => "on"}).sum(:numvcpus)
  end

  def instances_quota_used
    cloud_tenant.vms.where("power_state != ?", "unknown").count
  end

  def ram_quota_used
    Hardware.joins(:vm).where(:vms => {:cloud_tenant_id => cloud_tenant_id, :power_state => "on"}).sum(:memory_cpu)
  end

  # nova
  def floating_ips_quota_used
    # in reality, nova should not use the same quota used value as neutron ...
    # instead, if neutron is being used for networking (i.e., ems has network
    # service available), then show 0
    floatingip_quota_used
  end

  # neutron
  def floatingip_quota_used
    FloatingIp.where(:cloud_tenant_id => cloud_tenant_id).count
  end

  # nova
  def security_group_rules_quota_used
    # in reality, nova should not use the same quota used value as neutron ...
    # instead, if neutron is being used for networking (i.e., ems has network
    # service available), then show 0
    security_group_rule_quota_used
  end

  # neutron
  def security_group_rule_quota_used
    FirewallRule.joins("inner join security_groups on security_groups.id = firewall_rules.resource_id and firewall_rules.resource_type = 'SecurityGroup'").where("security_groups.cloud_tenant_id" => cloud_tenant_id).count
  end

  # nova
  def security_groups_quota_used
    # in reality, nova should not use the same quota used value as neutron ...
    # instead, if neutron is being used for networking (i.e., ems has network
    # service available), then show 0
    security_group_quota_used
  end

  # neutron
  def security_group_quota_used
    SecurityGroup.where(:cloud_tenant_id => cloud_tenant_id).count
  end

  def network_quota_used
    CloudNetwork.where(:cloud_tenant_id => cloud_tenant_id).count
  end

  def subnet_quota_used
    CloudSubnet.joins(:cloud_network).where("cloud_networks.cloud_tenant_id" => cloud_tenant_id).count
  end
end
