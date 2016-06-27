module MiddlewareServerHelper::TextualSummary
  include TextualMixins::TextualName
  #
  # Groups
  #

  def textual_group_properties
    %i(name hostname feed bind_addr product version)
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    %i(ems middleware_deployments middleware_datasources)
  end

  def textual_group_smart_management
    %i(tags)
  end

  #
  # Items
  #
  def textual_hostname
    @record.hostname
  end

  def textual_feed
    @record.feed
  end

  def textual_bind_addr
    {:label => _('Bind Address'),
     :value => @record.properties['Bound Address']}
  end

  def textual_product
    @record.product
  end

  def textual_version
    @record.properties['Version']
  end
end
