module ContainerGroupHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(namespace name creation_timestamp resource_version restart_policy dns_policy)
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
    {:label => "Creation Timestamp", :value => @record.creation_timestamp}
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
end
