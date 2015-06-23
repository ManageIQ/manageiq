module EmsContainerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(name type hostname ipaddress port zone cpu_cores
               memory_resources)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    items = []
    items.concat(%w(container_projects container_routes)) if @ems.kind_of?(EmsOpenshift)
    items.concat(%w(container_services container_replicators container_groups container_nodes))
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_status
    items = %w(refresh_status)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_smart_management
    items = %w{zone}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @ems.name}
  end

  def textual_type
    {:label => "Type", :value => @ems.emstype_description}
  end

  def textual_hostname
    {:label => "Hostname", :value => @ems.hostname}
  end

  def textual_ipaddress
    {:label => "IP Address", :value => @ems.ipaddress}
  end

  def textual_memory_resources
    {:label => "Aggregate Node Memory",
     :value => number_to_human_size(@ems.aggregate_memory * 1.megabyte,
                                    :precision => 0)}
  end

  def textual_cpu_cores
    {:label => "Aggregate Node CPU Cores",
     :value => @ems.aggregate_logical_cpus}
  end

  def textual_port
    @ems.supports_port? ? {:label => "Port", :value => @ems.port} : nil
  end

  def textual_zone
    {:label => "Managed by Zone", :image => "zone", :value => @ems.zone.name}
  end

  def textual_refresh_status
    last_refresh_status = @ems.last_refresh_status.titleize
    if @ems.last_refresh_date
      last_refresh_date = time_ago_in_words(@ems.last_refresh_date.in_time_zone(Time.zone)).titleize
      last_refresh_status << " - #{last_refresh_date} Ago"
    end
    {
      :label => "Last Refresh",
      :value => [{:value => last_refresh_status},
                 {:value => @ems.last_refresh_error.try(:truncate, 120)}],
      :title => @ems.last_refresh_error
    }
  end

  def textual_container_routes
    count_of_routes = @ems.number_of(:container_routes)
    label = ui_lookup(:tables => "container_routes")
    h = {:label => label, :image => "container_route", :value => count_of_routes}
    if count_of_routes > 0 && role_allows(:feature => "container_route_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'container_routes')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_container_projects
    count_of_projects = @ems.number_of(:container_projects)
    label = ui_lookup(:tables => "container_projects")
    h = {:label => label, :image => "container_project", :value => count_of_projects}
    if count_of_projects > 0 && role_allows(:feature => "container_project_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'container_projects')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_container_nodes
    count_of_nodes = @ems.number_of(:container_nodes)
    label = "Container Nodes"
    h     = {:label => label, :image => "container_node", :value => count_of_nodes}
    if count_of_nodes > 0 && role_allows(:feature => "container_node_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'container_nodes')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_container_services
    count_of_services = @ems.number_of(:container_services)
    label = "Container Services"
    h     = {:label => label, :image => "container_service", :value => count_of_services}
    if count_of_services > 0 && role_allows(:feature => "container_service_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'container_services')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_container_groups
    count_of_groups = @ems.number_of(:container_groups)
    label = "Container Groups"
    h     = {:label => label, :image => "container_group", :value => count_of_groups}
    if count_of_groups > 0 && role_allows(:feature => "container_group_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'container_groups')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_container_replicators
    count_of_replicators = @ems.number_of(:container_replicators)
    label = ui_lookup(:tables => "container_replicators")
    h     = {:label => label, :image => "container_replicator", :value => count_of_replicators}
    if count_of_replicators > 0 && role_allows(:feature => "container_replicator_show_list")
      h[:link]  = url_for(:action => 'show', :id => @ems, :display => 'container_replicators')
      h[:title] = "Show all #{label}"
    end
    h
  end
end
