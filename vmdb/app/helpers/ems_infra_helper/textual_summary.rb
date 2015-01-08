module EmsInfraHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{hostname ipaddress type port cpu_resources memory_resources cpus cpu_cores guid host_default_vnc_port_range}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{infrastructure_folders folders clusters hosts datastores vms templates}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_authentications
    items = %w{authentications}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_tags
    items = %w{zone tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_hostname
    {:label => "Hostname", :value => @ems.hostname}
  end

  def textual_ipaddress
    {:label => "IP Address", :value => @ems.ipaddress}
  end

  def textual_type
    {:label => "Type", :value => @ems.emstype_description}
  end

  def textual_port
    ["openstack", "openstack_infra", "rhevm"].include?(@ems.emstype) ? {:label => "API Port", :value => @ems.port} : nil
  end

  def textual_cpu_resources
    {:label => "Aggregate Host CPU Resources", :value => mhz_to_human_size(@ems.aggregate_cpu_speed)}
  end

  def textual_memory_resources
    {:label => "Aggregate Host Memory", :value => number_to_human_size(@ems.aggregate_memory * 1.megabyte,:precision=>0)}
  end

  def textual_cpus
    {:label => "Aggregate Host CPUs", :value => @ems.aggregate_physical_cpus}
  end

  def textual_cpu_cores
    {:label => "Aggregate Host CPU Cores", :value => @ems.aggregate_logical_cpus}
  end

  def textual_guid
    {:label => "Management Engine GUID", :value => @ems.guid}
  end

  def textual_infrastructure_folders
    label     = "Hosts & Clusters"
    available = @ems.number_of(:ems_folders) > 0 && @ems.ems_folder_root
    h         = {:label => label, :image => "hosts_and_clusters", :value => available ? "Available" : "N/A"}
    if available
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'ems_folders')
      h[:title] = "Show #{label}"
    end
    h
  end

  def textual_folders
    label     = "VMs & Templates"
    available = @ems.number_of(:ems_folders) > 0 && @ems.ems_folder_root
    h         = {:label => label, :image => "vms_and_templates", :value => available ? "Available" : "N/A"}
    if available
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'ems_folders', :vat => true)
      h[:title] = "Show Virtual Machines & Templates"
    end
    h
  end

  def textual_clusters
    label = "Clusters"
    num   = @ems.number_of(:ems_clusters)
    h     = {:label => label, :image => "cluster", :value => num}
    if num > 0 && role_allows(:feature => "ems_cluster_show_list")
      h[:link] = url_for(:action => 'show', :id => @ems, :display => 'ems_clusters')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_hosts
    label = "Hosts"
    num   = @ems.number_of(:hosts)
    h     = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'hosts')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_datastores
    label = ui_lookup(:tables=>"storages")
    num   = @ems.number_of(:storages)
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'storages')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_vms
    label = "VMs"
    num   = @ems.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'vms')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_templates
    label = "Templates"
    num = @ems.number_of(:miq_templates)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'miq_templates')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_authentications
    authentications = @ems.authentications
    return [{:label => "Default Authentication", :title => "None", :value => "None"}] if authentications.blank?

    authentications.collect do |auth|
      label =
        case auth.authtype
        when "default"; "Default"
        when "metrics"; "C & U Database"
        else;           "<Unknown>"
        end

      {:label => "#{label} Credentials", :value => auth.status || "None", :title => auth.status_details}
    end
  end

  def textual_zone
    {:label => "Managed by Zone", :image => "zone", :value => @ems.zone.name}
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

  def textual_host_default_vnc_port_range
    return nil unless @ems.is_a?(EmsVmware)
    value = @ems.host_default_vnc_port_start.blank? ?
        "" :
        "#{@ems.host_default_vnc_port_start} - #{@ems.host_default_vnc_port_end}"
    {:label => "Host Default VNC Port Range", :value => value}
  end

end
