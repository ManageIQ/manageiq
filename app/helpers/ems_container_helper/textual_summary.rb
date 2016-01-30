module EmsContainerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name type hostname port cpu_cores memory_resources)
  end

  def textual_group_relationships
    # Order of items should be from parent to child
    items = []
    items.concat(%i(container_projects))
    items.concat(%i(container_routes)) if @ems.respond_to?(:container_routes)
    items.concat(%i(container_services container_replicators container_groups containers container_nodes
                    container_image_registries container_images))
    items
  end

  def textual_group_status
    %i(refresh_status)
  end

  def textual_group_component_statuses
    labels = [_("Name"), _("Healthy"), _("Error")]
    h = {:labels => labels}
    h[:values] = @record.container_component_statuses.collect do |cs|
      [
        cs.name,
        cs.status,
        (cs.error || "")
      ]
    end
    h
  end

  def textual_group_smart_management
    %i(zone tags)
  end

  def textual_group_topology
    items = %w(topology)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
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

  def textual_memory_resources
    {:label => "Aggregate Node Memory",
     :value => number_to_human_size(@ems.aggregate_memory * 1.megabyte,
                                    :precision => 0)}
  end

  def textual_cpu_cores
    {:label => "Aggregate Node CPU Cores",
     :value => @ems.aggregate_cpu_total_cores}
  end

  def textual_port
    @ems.supports_port? ? @ems.port : nil
  end

  def textual_zone
    {:label => "Managed by Zone", :image => "zone", :value => @ems.zone.name}
  end

  def textual_refresh_status
    last_refresh_status = @ems.last_refresh_status.titleize
    if @ems.last_refresh_date
      last_refresh_date = time_ago_in_words(@ems.last_refresh_date.in_time_zone(Time.zone)).titleize
      last_refresh_status << " - #{last_refresh_date} Ago"
    end
    {
      :label => "Last Refresh",
      :value => [{:value => last_refresh_status},
                 {:value => @ems.last_refresh_error.try(:truncate, 120)}],
      :title => @ems.last_refresh_error
    }
  end

  def textual_topology
    {:label => N_('Topology'),
     :image => 'topology',
     :link  => url_for(:controller => 'container_topology', :action => 'show', :id => @ems.id),
     :title => N_("Show topology")}
  end
end
