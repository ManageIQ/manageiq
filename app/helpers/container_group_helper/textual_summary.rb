module ContainerGroupHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(name creation_timestamp resource_version restart_policy dns_policy ip)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    items = %w(ems container_project container_services containers container_node lives_on)
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

  def textual_restart_policy
    {:label => "Restart Policy", :value => @record.restart_policy}
  end

  def textual_dns_policy
    {:label => "DNS Policy", :value => @record.dns_policy}
  end

  def textual_ip
    {:label => "IP Address", :value => @record.ipaddress}
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
end
