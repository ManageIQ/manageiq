module ContainerSummaryHelper
  def textual_ems
    textual_link(@record.ext_management_system, :as         => ManageIQ::Providers::ContainerManager,
                                                :controller => 'ems_container')
  end

  def textual_container_project
    textual_link(@record.container_project)
  end

  def textual_container_group
    textual_link(@record.container_group)
  end

  def textual_container_projects
    textual_link(@record.container_projects)
  end

  def textual_container_routes
    textual_link(@record.container_routes)
  end

  def textual_container_service
    textual_link(@record.container_service)
  end

  def textual_container_services
    textual_link(@record.container_services)
  end

  def textual_container_replicator
    textual_link(@record.container_replicator)
  end

  def textual_container_replicators
    textual_link(@record.container_replicators)
  end

  def textual_container_groups
    textual_link(@record.container_groups)
  end

  def textual_containers
    textual_link(@record.containers, :feature => "containers") # should it be container_show_list?
  end

  def textual_container_nodes
    textual_link(@record.container_nodes)
  end

  def textual_container_node
    textual_link(@record.container_node)
  end

  def textual_group_container_labels
    textual_key_value_group(@record.labels.to_a)
  end

  def textual_group_container_selectors
    textual_key_value_group(@record.selector_parts.to_a)
  end

  def textual_container_image
    textual_link(@record.container_image)
  end

  def textual_container_images
    textual_link(@record.container_images)
  end

  def textual_container_image_registry
    object = @record.container_image_registry

    if object.nil?
      {
        :label => ui_lookup(:model => ContainerImageRegistry.name),
        :image => "container_image_registry_unknown",
        :value => "Unknown image source"
      }
    else
      textual_link(@record.container_image_registry)
    end
  end

  def textual_container_image_registries
    textual_link(@record.container_image_registries)
  end

  private

  def textual_key_value_group(items)
    items.collect { |item| {:label => item.name.to_s, :value => item.value.to_s} }
  end
end
