module ContainerListnavHelper
  def listnav_ems
    listnav_link_to(@record.ext_management_system, :as => EmsContainer)
  end

  def listnav_container_project
    listnav_link_to(@record.container_project)
  end

  def listnav_container_group
    listnav_link_to(@record.container_group)
  end

  def listnav_container_projects
    listnav_link_to(@record.container_projects)
  end

  def listnav_container_routes
    listnav_link_to(@record.container_routes)
  end

  def listnav_container_service
    listnav_link_to(@record.container_service)
  end

  def listnav_container_services
    listnav_link_to(@record.container_services)
  end

  def listnav_container_replicator
    listnav_link_to(@record.container_replicator)
  end

  def listnav_container_replicators
    listnav_link_to(@record.container_replicators)
  end

  def listnav_container_groups
    listnav_link_to(@record.container_groups)
  end

  def listnav_containers
    listnav_link_to(@record.containers, :feature => "containers") # should it be container_show_list?
  end

  def listnav_container_nodes
    listnav_link_to(@record.container_nodes)
  end

  def listnav_container_node
    listnav_link_to(@record.container_node)
  end

  def listnav_container_image
    listnav_link_to(@record.container_image)
  end

  def listnav_container_images
    listnav_link_to(@record.container_images)
  end

  def listnav_container_image_registry
    listnav_link_to(@record.container_image_registry)
  end

  def listnav_container_image_registries
    listnav_link_to(@record.container_image_registries)
  end

  def listnav_link_to(target, **opts, &blk)
    case target
      when ActiveRecord::Relation
        listnav_collection_link(target, **opts, &blk)
      else
        listnav_object_link(target, **opts, &blk)
    end
  end

  def listnav_collection_link(collection, as: nil, feature: nil)
    klass = as || collection.klass.base_model
    feature ||= "#{klass.name.underscore}_show_list"
    label = ui_lookup(:models => klass.name)

    if role_allows(:feature => feature)
      count = collection.count
      if count == 0
        # needs to be inside li.disabled tag
        h = link_to("#{label} (0)", "#")
      else
        # needs to be inside li
        if count == 1
          collection = collection.first
          klass = collection.class.base_model
          h = link_to("#{label} (#{count})",
                      {:controller => "#{klass.name.underscore}", :action => 'show', :id => collection},
                      :title => _("View #{label} #{collection.name}"))
        else
          h = link_to("#{label} (#{count})",
                      {:action => 'show', :id => @record, :display => "#{klass}"},
                      :title => _("Show #{label}"))
        end
      end
    end
    h
  end

  def listnav_object_link(object, as: nil, feature: nil)
    return if object.nil?

    klass = as || object.class.base_model
    feature ||= "#{klass.name.underscore}_show"
    label = ui_lookup(:model => klass.name)

    if klass == ExtManagementSystem && role_allows(:feature => "ems_container_show")
      h = link_to("#{label}: #{object.name}",
                  {:controller => "ems_container", :action => 'show', :id => object.id.to_s},
                  :title => _("Show this #{@record.class.model_name.human.downcase}'s parent #{label}"))
    elsif role_allows(:feature => feature)
      h = link_to("#{label}: #{object.name}",
                  {:controller => "#{klass.name.underscore}", :action => 'show', :id => object},
                  :title => _("View #{label} #{object.name}"))
    end
    #should be inside <li>
    h
  end
end
