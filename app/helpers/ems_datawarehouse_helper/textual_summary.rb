module EmsDatawarehouseHelper::TextualSummary
  include TextualMixins::TextualRefreshStatus
  #
  # Groups
  #

  def textual_group_properties
    %i(name type hostname port)
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    []
  end

  def textual_group_status
    %i(refresh_status)
  end

  def textual_group_smart_management
    %i(tags)
  end

  #
  # Items
  #

  def textual_name
    @ems.name
  end

  def textual_type
    @ems.emstype_description
  end

  def textual_hostname
    @ems.hostname
  end

  def textual_port
    @ems.supports_port? ? @ems.port : nil
  end
end
