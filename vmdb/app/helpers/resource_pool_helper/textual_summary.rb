module ResourcePoolHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{vapp aggregate_cpu_speed aggregate_cpu_memory aggregate_physical_cpus aggregate_logical_cpus aggregate_vm_memory aggregate_vm_cpus}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{parent_datacenter parent_cluster parent_host direct_vms allvms_size total_vms}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_configuration
    items = %w{memory_reserve memory_reserve_expand memory_limit memory_shares memory_shares_level cpu_reserve cpu_reserve_expand cpu_limit cpu_shares cpu_shares_level}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_smart_management
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_vapp
    {:label => "vApp", :value => @record.vapp}
  end

  def textual_aggregate_cpu_speed
    # TODO: Why aren't we using mhz_to_human_size here?
    {:label => "Total Host CPU Resources", :value => "#{number_with_delimiter(@record.aggregate_cpu_speed)} MHz"}
  end

  def textual_aggregate_cpu_memory
    {:label => "Total Host Memory", :value => number_to_human_size(@record.aggregate_memory.megabytes, :precision => 0)}
  end

  def textual_aggregate_physical_cpus
    {:label => "Total Host CPUs", :value => number_with_delimiter(@record.aggregate_physical_cpus)}
  end

  def textual_aggregate_logical_cpus
    {:label => "Total Host CPU Cores", :value => number_with_delimiter(@record.aggregate_logical_cpus)}
  end

  def textual_aggregate_vm_memory
    {:label => "Total Configured VM Memory", :value => number_to_human_size(@record.aggregate_vm_memory.megabytes)}
  end

  def textual_aggregate_vm_cpus
    {:label => "Total Configured VM CPUs", :value => number_with_delimiter(@record.aggregate_vm_cpus)}
  end

  def textual_parent_datacenter
    {:label => "Parent Datacenter", :image => "datacenter", :value => @record.v_parent_datacenter || "None"}
  end

  def textual_parent_cluster
    cluster = @record.parent_cluster
    h = {:label => "Parent Cluster", :image => "ems_cluster", :value => (cluster.nil? ? "None" : cluster.name)}
    if cluster && role_allows(:feature => "ems_cluster_show")
      h[:title] = "Show Parent Cluster '#{cluster.name}'"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => cluster)
    end
    h
  end

  def textual_parent_host
    host = @record.parent_host
    h = {:label => "Parent Host", :image => "host", :value => (host.nil? ? "None" : host.name)}
    if host && role_allows(:feature => "host_show")
      h[:title] = "Show Parent Host '#{host.name}'"
      h[:link]  = url_for(:controller => 'host', :action => 'show', :id => host)
    end
    h
  end

  def textual_direct_vms
    num = @record.v_direct_vms
    h = {:label => "Direct VMs", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show VMs in this Resource Pool, but not in Resource Pools below"
      h[:link]  = url_for(:controller => 'resource_pool', :action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_allvms_size
    num = @record.total_vms
    h = {:label => "All VMs", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show all VMs in this Resource Pool"
      h[:link]  = url_for(:controller => 'resource_pool', :action => 'show', :id => @record, :display => 'all_vms')
    end
    h
  end

  def textual_total_vms
    num = @record.v_total_vms
    h = {:label => "All VMs (Tree View)", :image => "vm", :value => num}
    # TODO: Why is this role_allows resource_pool_show_list but the previous 2 methods are for vm_show_list
    if num > 0 && role_allows(:feature => "resource_pool_show_list")
      h[:title] = "Show tree of all VMs in this Resource Pool"
      h[:link]  = url_for(:controller => 'resource_pool', :action => 'show', :id => @record, :display => 'descendant_vms')
    end
    h
  end

  def textual_memory_reserve
    value = @record.memory_reserve
    return nil if value.nil?
    {:label => "Memory Reserve", :value => value}
  end

  def textual_memory_reserve_expand
    value = @record.memory_reserve_expand
    return nil if value.nil?
    {:label => "Memory Reserve Expand", :value => value}
  end

  def textual_memory_limit
    value = @record.memory_limit
    return nil if value.nil?
    {:label => "Memory Limit", :value => (value == -1 ? "Unlimited" : value)}
  end

  def textual_memory_shares
    value = @record.memory_shares
    return nil if value.nil?
    {:label => "Memory Shares", :value => value}
  end

  def textual_memory_shares_level
    value = @record.memory_shares_level
    return nil if value.nil?
    {:label => "Memory Shares Level", :value => value}
  end

  def textual_cpu_reserve
    value = @record.cpu_reserve
    return nil if value.nil?
    {:label => "CPU Reserve", :value => value}
  end

  def textual_cpu_reserve_expand
    value = @record.cpu_reserve_expand
    return nil if value.nil?
    {:label => "CPU Reserve Expand", :value => value}
  end

  def textual_cpu_limit
    value = @record.cpu_limit
    return nil if value.nil?
    {:label => "CPU Limit", :value => (value == -1 ? "Unlimited" : value)}
  end

  def textual_cpu_shares
    value = @record.cpu_shares
    return nil if value.nil?
    {:label => "CPU Shares", :value => value}
  end

  def textual_cpu_shares_level
    value = @record.cpu_shares_level
    return nil if value.nil?
    {:label => "CPU Shares Level", :value => value}
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h = {:label => label}
    tags = session[:assigned_filters]
    if tags.empty?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
  end
end
