class ContainerTopologyService < TopologyService

  def initialize(provider_id)
    @provider_id = provider_id
    @providers = retrieve_providers(ManageIQ::Providers::ContainerManager, @provider_id)
  end

  def build_topology
    topo_items = {}
    links = []

    entity_relationships = {:ContainerManager => {:ContainerNodes =>
                                                      {:ContainerGroups =>
                                                         {:Containers => nil, :ContainerReplicator => nil, :ContainerServices => {:ContainerRoutes => nil}},
                                                       :lives_on => {:Host => nil}
                                                   }}}

    preloaded = @providers.includes(:container_nodes => [:container_groups => [:containers, :container_replicator, :container_services => [:container_routes]],
                                                         :lives_on => [:host]])
    preloaded.each do |entity|
      topo_items, links = build_recursive_topology(entity, entity_relationships[:ContainerManager], topo_items, links)
    end

    icons = {:ContainerReplicator => {:type => "glyph", :icon => "\uE624", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-replicator
             :ContainerGroup      => {:type => "glyph", :icon => "\uF1B3", :fontfamily => "FontAwesome"},             # fa-cubes
             :ContainerNode       => {:type => "glyph", :icon => "\uE621", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-container-node
             :ContainerService    => {:type => "glyph", :icon => "\uE61E", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-service
             :ContainerRoute      => {:type => "glyph", :icon => "\uE625", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-route
             :Container           => {:type => "glyph", :icon => "\uF1B2", :fontfamily => "FontAwesome"},             # fa-cube
             :Host                => {:type => "glyph", :icon => "\uE600", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-screen
             :Vm                  => {:type => "glyph", :icon => "\uE90f", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-virtual-machine
             :Kubernetes          => {:type => "image", :icon => provider_icon(:Kubernetes)},
             :Openshift           => {:type => "image", :icon => provider_icon(:Openshift)},
             :OpenshiftEnterprise => {:type => "image", :icon => provider_icon(:OpenshiftEnterprise)},
             :Atomic              => {:type => "image", :icon => provider_icon(:Atomic)},
             :AtomicEnterprise    => {:type => "image", :icon => provider_icon(:AtomicEnterprise)}
    }

    populate_topology(topo_items, links, build_kinds, icons)
  end

  def provider_icon(provider_type)
    file_name = 'svg/vendor-' + provider_type.to_s.underscore.downcase + '.svg'
    ActionController::Base.helpers.image_path(file_name)
  end

  def entity_display_type(entity)
    if entity.kind_of?(ManageIQ::Providers::ContainerManager)
      entity.class.short_token
    elsif entity.kind_of?(ContainerGroup)
      "Pod"
    else
      name = entity.class.name.demodulize
      if name.start_with? "Container"
        if name.length > "Container".length # container related entities such as ContainerService
          name["Container".length..-1]
        else
          "Container" # the container entity itself
        end
      else
        if entity.kind_of?(Vm)
          name.upcase # turn Vm to VM because it's an abbreviation
        else
          name # non container entities such as Host
        end
      end
    end
  end

  def build_entity_data(entity)
    data = build_base_entity_data(entity)
    data.merge!(:status       => entity_status(entity),
                :display_kind => entity_display_type(entity))

    if entity.kind_of?(Host) || entity.kind_of?(Vm)
      data.merge!(:provider => entity.ext_management_system.name)
    end

    data
  end

  def entity_status(entity)
    if entity.kind_of?(Host) || entity.kind_of?(Vm)
      status = entity.power_state.capitalize
    elsif entity.kind_of?(ContainerNode)
      status = 'Unknown'
      entity.container_conditions.each do |condition|
        if condition.try(:name) == 'Ready' && condition.try(:status) == 'True'
          status = condition.name
        else
          status = 'NotReady'
        end
      end
    elsif entity.kind_of?(ContainerGroup)
      status = entity.phase
    elsif entity.kind_of?(Container)
      status = entity.state.capitalize
    elsif entity.kind_of?(ContainerReplicator)
      status = (entity.current_replicas == entity.replicas) ? 'OK' : 'Warning'
    elsif entity.kind_of?(ManageIQ::Providers::ContainerManager)
      status = entity.authentications.empty? ? 'Unknown' : entity.authentications.first.status.capitalize
    else
      status = 'Unknown'
    end
    status
  end

  def build_kinds
    kinds = [:ContainerReplicator, :ContainerGroup, :Container, :ContainerNode,
             :ContainerService, :Host, :Vm, :ContainerRoute, :ContainerManager]
    build_legend_kinds(kinds)
  end
end
