module MiddlewareDeploymentHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name status nativeid)
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    %i(ems middleware_server)
  end

  def textual_status
    @record.status
  end
end
