module ContainerGroupHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(namespace name creation_timestamp resource_version restart_policy dns_policy ip)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    items = %w(ems services containers container_node lives_on)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_namespace
    {:label => "Namespace", :value => @record.namespace}
  end

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_creation_timestamp
    {:label => "Creation Timestamp", :value => format_timezone(@record.creation_timestamp)}
  end

  def textual_resource_version
    {:label => "Resource Version", :value => @record.resource_version}
  end

  def textual_restart_policy
    {:label => "Restart Policy", :value => @record.restart_policy}
  end

  def textual_dns_policy
    {:label => "DNS Policy", :value => @record.dns_policy}
  end

  def textual_ip
    {:label => "IP Address", :value => @record.ipaddress}
  end

  def textual_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_container")
    h = {:label => label, :image => "vendor-#{ems.image_name}", :value => ems.name}
    if role_allows(:feature => "ems_container_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_container', :action => 'show', :id => ems)
    end
    h
  end

  def textual_containers
    num_of_containers = @record.number_of(:containers)
    label = ui_lookup(:tables => "containers")
    h     = {:label => label, :image => "container", :value => num_of_containers}
    if num_of_containers > 0 && role_allows(:feature => "containers")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'containers')
      h[:title] = "View #{label}"
    end
    h
  end

  def textual_container_node
    node = @record.container_node
    return nil if node.nil?
    label = ui_lookup(:table => "container_node")
    h     = {:label => label, :image => "container_node", :value => node.name}
    if role_allows(:feature => "container_node_show")
      h[:link]  = url_for(:action => 'show', :id => node, :controller => 'container_node')
      h[:title] = "View #{label} #{(@record.container_node.name)}"
    end
    h
  end

  def textual_lives_on
    lives_on_ems = @record.container_node.try(:lives_on).try(:ext_management_system)
    return nil if lives_on_ems.nil?
    # TODO: handle the case where the node is a bare-metal
    lives_on_entity_name = lives_on_ems.kind_of?(EmsCloud) ? "Instance" : "Virtual Machine"
    {
      :label => "Underlying #{lives_on_entity_name}",
      :image => "vendor-#{lives_on_ems.image_name}",
      :value => "#{@record.container_node.lives_on.name}",
      :link  => url_for(
        :action     => 'show',
        :controller => 'vm_or_template',
        :id         => @record.container_node.lives_on.id
      )
    }
  end

  def textual_services
    num_of_services = @record.number_of(:container_services)
    label = ui_lookup(:tables => "container_service")
    h = {:label => label, :image => "container_service", :value => num_of_services}
    if num_of_services > 0 && role_allows(:feature => "container_service_show")
      h[:link] = url_for(:action => 'show', :controller => 'container_group', :display => 'container_services')
    end
    h
  end
end
