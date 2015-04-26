module ContainerNodeHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(name creation_timestamp resource_version num_cpu_cores memory
               identity_system identity_machine identity_infra)
    items.collect {|m| send("textual_#{m}")}.flatten.compact
  end

  def textual_group_relationships
    items = %w(ems container_groups)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_creation_timestamp
    {:label => "Creation Timestamp", :value => format_timezone(@record.creation_timestamp)}
  end

  def textual_resource_version
    {:label => "Resource Version", :value => @record.resource_version}
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

  def textual_num_cpu_cores
    {:label => "Number of CPU Cores",
     :value => @record.hardware.nil? ? "N/A" : @record.hardware.logical_cpus}
  end

  def textual_memory
    if @record.try(:hardware).try(:memory_cpu)
      memory = number_to_human_size(
        @record.hardware.memory_cpu * 1.megabyte, :precision => 0)
    else
      memory = "N/A"
    end
    {:label => "Memory", :value => memory}
  end

  def textual_identity_system
    {:label => "System BIOS UUID",
     :value => @record.identity_system.nil? ? "N/A" : @record.identity_system}
  end

  def textual_identity_machine
    {:label => "Machine ID",
     :value => @record.identity_machine.nil? ? "N/A" : @record.identity_machine}
  end

  def textual_identity_infra
    {:label => "Infrastructure Machine ID", :value =>
      @record.identity_infra.nil?  ? "N/A" : @record.identity_infra}
  end

  def textual_container_groups
    num_of_container_groups = @record.number_of(:container_groups)
    label = ui_lookup(:tables => "container_groups")
    h = {:label => label, :image => "container_group", :value => num_of_container_groups}
    if num_of_container_groups > 0 && role_allows(:feature => "container_group_show")
      h[:link] = url_for(:action => 'show', :controller => 'container_node', :display => 'container_groups')
    end
    h
  end
end
