module ContainerNodeHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(name creation_timestamp resource_version num_cpu_cores memory
               identity_system identity_machine identity_infra runtime_version
               kubelet_version proxy_version os_distribution kernel_version)
    items.collect {|m| send("textual_#{m}")}.flatten.compact
  end

  def textual_group_relationships
    items = %w(ems container_groups lives_on)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_conditions
    labels = [_("Name"), _("Status"), _("Last Transition Time"), _("Reason")]
    h = {:labels => labels}
    h[:values] = @record.container_node_conditions.collect do |condition|
      [
        condition.name,
        condition.status,
        (condition.last_transition_time || ""),
        (condition.reason || "")
      ]
    end
    h
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

  def textual_lives_on
    lives_on_ems = @record.lives_on.try(:ext_management_system)
    return nil if lives_on_ems.nil?
    # TODO: handle the case where the node is a bare-metal
    lives_on_entity_name = lives_on_ems.kind_of?(EmsCloud) ? "Instance" : "Virtual Machine"
    {
      :label => "Underlying #{lives_on_entity_name}",
      :image => "vendor-#{lives_on_ems.image_name}",
      :value => "#{@record.lives_on.name}",
      :link  => url_for(
        :action     => 'show',
        :controller => 'vm_or_template',
        :id         => @record.lives_on.id
      )
    }
  end

  def textual_runtime_version
    {:label => "Runtime Version", :value =>
        @record.container_runtime_version.nil?  ? "N/A" : @record.container_runtime_version}
  end

  def textual_kubelet_version
    {:label => "Kubelet Version", :value =>
        @record.kubernetes_kubelet_version.nil?  ? "N/A" : @record.kubernetes_kubelet_version}
  end

  def textual_proxy_version
    {:label => "Proxy Version", :value =>
        @record.kubernetes_proxy_version.nil?  ? "N/A" : @record.kubernetes_proxy_version}
  end

  def textual_os_distribution
    if @record.computer_system.nil? || @record.computer_system.operating_system.nil?
      distribution = "N/A"
    else
      distribution = @record.computer_system.operating_system.distribution
    end
    {:label => "Operating System Distribution", :value => distribution}
  end

  def textual_kernel_version
    if @record.computer_system.nil? || @record.computer_system.operating_system.nil?
      version = "N/A"
    else
      version = @record.computer_system.operating_system.kernel_version
    end
    {:label => "Kernel Version", :value => version}
  end
end
