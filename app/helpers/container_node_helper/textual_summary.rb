module ContainerNodeHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name creation_timestamp resource_version num_cpu_cores memory
       max_container_groups identity_system identity_machine identity_infra runtime_version
       kubelet_version proxy_version os_distribution kernel_version)
  end

  def textual_group_relationships
    %i(ems container_routes container_services container_replicators container_groups containers lives_on)
  end

  def textual_group_conditions
    labels = [_("Name"), _("Status"), _("Last Transition Time"), _("Reason")]
    h = {:labels => labels}
    h[:values] = @record.container_conditions.collect do |condition|
      [
        condition.name,
        condition.status,
        (condition.last_transition_time || ""),
        (condition.reason || "")
      ]
    end
    h
  end

  def textual_group_smart_management
    items = %w(tags)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    @record.name
  end

  def textual_creation_timestamp
    format_timezone(@record.creation_timestamp)
  end

  def textual_resource_version
    @record.resource_version
  end

  def textual_num_cpu_cores
    {:label => "Number of CPU Cores",
     :value => @record.hardware.nil? ? "N/A" : @record.hardware.cpu_total_cores}
  end

  def textual_memory
    if @record.try(:hardware).try(:memory_mb)
      memory = number_to_human_size(
        @record.hardware.memory_mb * 1.megabyte, :precision => 0)
    else
      memory = "N/A"
    end
    {:label => "Memory", :value => memory}
  end

  def textual_max_container_groups
    {:label => "Max Pods Capacity",
     :value => @record.max_container_groups.nil? ? "N/A" : @record.max_container_groups}
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
      @record.identity_infra.nil? ? "N/A" : @record.identity_infra}
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
    @record.container_runtime_version || "N/A"
  end

  def textual_kubelet_version
    @record.kubernetes_kubelet_version || "N/A"
  end

  def textual_proxy_version
    @record.kubernetes_proxy_version || "N/A"
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
    @record.computer_system.try(:operating_system).try(:kernel_version) || "N/A"
  end
end
