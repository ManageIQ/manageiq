module ContainerTemplateHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name creation_timestamp resource_version)
  end

  def textual_group_relationships
    %i(ems container_project)
  end

  def textual_group_smart_management
    items = %w(tags)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_objects
    labels = [_("Kind"), _("Name")]
    values = @record.objects.collect { |obj| [obj[:kind], obj[:metadata][:name] || obj[:metadata][:generateName]] }
    {:labels => labels, :values => values}
  end

  def textual_group_parameters
    labels = [_("Name"), _("Value"), _("Required")]
    values = @record.container_template_parameters.reorder('required').collect do |param|
      req = param.required || false
      req = 'auto-generated' if param.generate.present?
      [param.name, param.value, req]
    end
    {:labels => labels, :values => values}
  end
end
