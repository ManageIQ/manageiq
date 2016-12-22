module EmsMiddlewareHelper::TextualSummary
  include TextualMixins::TextualRefreshStatus
  #
  # Groups
  #

  def textual_group_properties
    %i(name type hostname port)
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    items = []
    items.concat(%i(middleware_domains middleware_servers middleware_deployments middleware_datasources
      middleware_messagings))
  end

  def textual_group_status
    %i(refresh_status)
  end

  def textual_group_smart_management
    %i(tags)
  end

  def textual_group_topology
    items = %w(topology)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    @record.name
  end

  def textual_type
    @record.emstype_description
  end

  def textual_hostname
    @record.hostname
  end

  def textual_port
    @record.supports_port? ? @record.port : nil
  end

  def textual_topology
    {:label => _('Topology'),
     :icon  => "pficon pficon-topology",
     :link  => url_for(:controller => 'middleware_topology', :action => 'show', :id => @record.id),
     :title => _('Show topology')}
  end
end
