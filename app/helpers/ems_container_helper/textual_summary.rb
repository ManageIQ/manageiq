module EmsContainerHelper::TextualSummary
  include TextualMixins::TextualRefreshStatus
  include TextualMixins::TextualAuthenticationsStatus
  include TextualMixins::TextualMetricsStatus
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
                    container_image_registries container_images volumes container_builds container_templates))
    items
  end

  def textual_group_status
    textual_authentications_status + %i(authentications_status metrics_status refresh_status)
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
    {:label => _("Aggregate Node Memory"),
     :value => number_to_human_size(@ems.aggregate_memory * 1.megabyte,
                                    :precision => 0)}
  end

  def textual_cpu_cores
    {:label => _("Aggregate Node CPU Cores"),
     :value => @ems.aggregate_cpu_total_cores}
  end

  def textual_port
    @ems.supports_port? ? @ems.port : nil
  end

  def textual_zone
    {:label => _("Managed by Zone"), :image => "100/zone.png", :value => @ems.zone.name}
  end

  def textual_topology
    {:label => _('Topology'),
     :image => '100/topology.png',
     :link  => polymorphic_path(@ems, :display => 'topology'),
     :title => _("Show topology")}
  end

  def textual_volumes
    count_of_volumes = @ems.number_of(:persistent_volumes)
    label = ui_lookup(:tables => "volume")
    h     = {:label => label, :image => "100/container_volume.png", :value => count_of_volumes}
    if count_of_volumes > 0 && role_allows?(:feature => "persistent_volume_show_list")
      h[:link]  = ems_container_path(@ems.id, :display => 'persistent_volumes')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_endpoints
    return unless @ems.connection_configurations.hawkular

    [{:label => _('Hawkular Host Name'),
      :value => @ems.connection_configurations.hawkular.endpoint.hostname},
     {:label => _('Hawkular API Port'),
      :value => @ems.connection_configurations.hawkular.endpoint.port}]
  end

  def textual_miq_custom_attributes
    attrs = @record.custom_attributes
    return nil if attrs.blank?
    attrs.collect { |a| {:label => a.name.tr("_", " "), :value => a.value} }
  end
end
