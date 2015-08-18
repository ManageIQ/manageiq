module ContainerProjectHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name display_name creation_timestamp resource_version)
  end

  def textual_group_relationships
    %i(ems container_routes container_services container_replicators container_groups container_nodes)
  end

  def textual_group_smart_management
    items = %w(tags)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_quota
    {
      :labels => [_("Name"), _("Resource"), _("Desired"), _("Enforced"), _("Observed")],
      :values => collect_quota_items
    }
  end

  def collect_quota_items
    rows = []
    @record.container_quota_items.each do |item|
      rows << [
        item.container_quota.name,
        item.resource,
        item.quota_desired,
        item.quota_enforced,
        item.quota_observed,
      ]
    end
    rows
  end

  #
  # Items
  #

  def textual_name
    @record.name
  end

  def textual_display_name
    @record.display_name
  end

  def textual_creation_timestamp
    format_timezone(@record.creation_timestamp)
  end

  def textual_resource_version
    @record.resource_version
  end
end
