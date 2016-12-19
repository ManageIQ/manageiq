module ResourcePoolHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(vapp aggregate_cpu_speed aggregate_cpu_memory aggregate_physical_cpus aggregate_cpu_total_cores aggregate_vm_memory aggregate_vm_cpus)
  end

  def textual_group_relationships
    %i(parent_datacenter parent_cluster parent_host direct_vms allvms_size total_vms)
  end

  def textual_group_configuration
    %i(memory_reserve memory_reserve_expand memory_limit memory_shares memory_shares_level cpu_reserve cpu_reserve_expand cpu_limit cpu_shares cpu_shares_level)
  end

  def textual_group_smart_management
    %i(tags)
  end

  #
  # Items
  #

  def textual_vapp
    {:label => _("vApp"), :value => @record.vapp}
  end

  def textual_aggregate_cpu_speed
    # TODO: Why aren't we using mhz_to_human_size here?
    {:label => _("Total %{title} CPU Resources") % {:title => title_for_host},
     :value => "#{number_with_delimiter(@record.aggregate_cpu_speed)} MHz"}
  end

  def textual_aggregate_cpu_memory
    {:label => _("Total %{title} Memory") % {:title => title_for_host},
     :value => number_to_human_size(@record.aggregate_memory.megabytes, :precision => 0)}
  end

  def textual_aggregate_physical_cpus
    {:label => _("Total %{title} CPUs") % {:title => title_for_host},
     :value => number_with_delimiter(@record.aggregate_physical_cpus)}
  end

  def textual_aggregate_cpu_total_cores
    {:label => _("Total %{title} CPU Cores") % {:title => title_for_host},
     :value => number_with_delimiter(@record.aggregate_cpu_total_cores)}
  end

  def textual_aggregate_vm_memory
    {:label => _("Total Configured VM Memory"), :value => number_to_human_size(@record.aggregate_vm_memory.megabytes)}
  end

  def textual_aggregate_vm_cpus
    {:label => _("Total Configured VM CPUs"), :value => number_with_delimiter(@record.aggregate_vm_cpus)}
  end

  def textual_parent_datacenter
    {:label => _("Parent Datacenter"), :icon => "fa fa-building-o", :value => @record.v_parent_datacenter || _("None")}
  end

  def textual_parent_cluster
    cluster = @record.parent_cluster
    h = {:label => _("Parent '%{title}'") % {:title => title_for_cluster},
         :icon  => "pficon pficon-cluster",
         :value => (cluster.nil? ? _("None") : cluster.name)}
    if cluster && role_allows?(:feature => "ems_cluster_show")
      h[:title] = _("Show Parent %{title} %{name}") % {:title => title_for_cluster, :name => cluster.name}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => cluster)
    end
    h
  end

  def textual_parent_host
    host = @record.parent_host
    h = {:label => _("Parent %{title}") % {:title => title_for_host},
         :icon  => "pficon pficon-screen",
         :value => (host.nil? ? _("None") : host.name)}
    if host && role_allows?(:feature => "host_show")
      h[:title] = _("Show Parent %{title} '%{name}'") % {:title => title_for_host, :name => host.name}
      h[:link]  = url_for(:controller => 'host', :action => 'show', :id => host)
    end
    h
  end

  def textual_direct_vms
    num = @record.v_direct_vms
    h = {:label => _("Direct VMs"), :icon => "pficon pficon-virtual-machine", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:title] = _("Show VMs in this Resource Pool, but not in Resource Pools below")
      h[:link]  = url_for(:controller => 'resource_pool', :action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_allvms_size
    num = @record.total_vms
    h = {:label => _("All VMs"), :icon => "pficon pficon-virtual-machine", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:title] = _("Show all VMs in this Resource Pool")
      h[:link]  = url_for(:controller => 'resource_pool', :action => 'show', :id => @record, :display => 'all_vms')
    end
    h
  end

  def textual_total_vms
    num = @record.v_total_vms
    h = {:label => _("All VMs (Tree View)"), :icon => "pficon pficon-virtual-machine", :value => num}
    # TODO: Why is this role_allows? resource_pool_show_list but the previous 2 methods are for vm_show_list
    if num > 0 && role_allows?(:feature => "resource_pool_show_list")
      h[:title] = _("Show tree of all VMs in this Resource Pool")
      h[:link]  = url_for(:controller => 'resource_pool', :action => 'show', :id => @record, :display => 'descendant_vms')
    end
    h
  end

  def textual_memory_reserve
    value = @record.memory_reserve
    return nil if value.nil?
    {:label => _("Memory Reserve"), :value => value}
  end

  def textual_memory_reserve_expand
    value = @record.memory_reserve_expand
    return nil if value.nil?
    {:label => _("Memory Reserve Expand"), :value => value}
  end

  def textual_memory_limit
    value = @record.memory_limit
    return nil if value.nil?
    {:label => _("Memory Limit"), :value => (value == -1 ? _("Unlimited") : value)}
  end

  def textual_memory_shares
    value = @record.memory_shares
    return nil if value.nil?
    {:label => _("Memory Shares"), :value => value}
  end

  def textual_memory_shares_level
    value = @record.memory_shares_level
    return nil if value.nil?
    {:label => _("Memory Shares Level"), :value => value}
  end

  def textual_cpu_reserve
    value = @record.cpu_reserve
    return nil if value.nil?
    {:label => _("CPU Reserve"), :value => value}
  end

  def textual_cpu_reserve_expand
    value = @record.cpu_reserve_expand
    return nil if value.nil?
    {:label => _("CPU Reserve Expand"), :value => value}
  end

  def textual_cpu_limit
    value = @record.cpu_limit
    return nil if value.nil?
    {:label => _("CPU Limit"), :value => (value == -1 ? _("Unlimited") : value)}
  end

  def textual_cpu_shares
    value = @record.cpu_shares
    return nil if value.nil?
    {:label => _("CPU Shares"), :value => value}
  end

  def textual_cpu_shares_level
    value = @record.cpu_shares_level
    return nil if value.nil?
    {:label => _("CPU Shares Level"), :value => value}
  end
end
