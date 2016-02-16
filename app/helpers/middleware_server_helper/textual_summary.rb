module MiddlewareServerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name hostname bind_addr product version)
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    %i(ems middleware_deployments)
  end

  def textual_group_smart_management
    %i(tags)
  end

  #
  # Items
  #

  def textual_name
    @record.name
  end

  def textual_hostname
    @record.hostname
  end

  def textual_bind_addr
    {:label => 'Bind Address',
     :value => @record.properties['Bound Address']}
  end

  def textual_product
    @record.product
  end

  def textual_version
    @record.properties['Version']
  end
end
