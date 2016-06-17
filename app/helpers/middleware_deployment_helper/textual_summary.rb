module MiddlewareDeploymentHelper::TextualSummary
  include TextualMixins::TextualName
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

  def textual_group_smart_management
    %i(tags)
  end

  def textual_nativeid
    @record.nativeid
  end

  def textual_status
    @record.status
  end
end
