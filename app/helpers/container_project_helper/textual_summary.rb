module ContainerProjectHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name display_name creation_timestamp resource_version)
  end

  def textual_group_relationships
    %i(ems container_routes container_services container_replicators container_groups container_nodes container_images
       container_templates)
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

  def textual_limits
    {
      :labels => [_("Name"), _("Type"), _("Resource"), _("Max"), _("Min"), _("Default Limit"),
                  _("Default Request"), _("Limit Request Ratio")],
      :values => collect_limit_items
    }
  end

  def collect_limit_items
    rows = []
    @record.container_limit_items.each do |item|
      rows << [
        item.container_limit.name,
        item.item_type,
        item.resource,
        item.max,
        item.min,
        item.default,
        item.default_request,
        item.max_limit_request_ratio
      ]
    end
    rows
  end

  #
  # Items
  #

  def textual_display_name
    @record.display_name
  end
end
