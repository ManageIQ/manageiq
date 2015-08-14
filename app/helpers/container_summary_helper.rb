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

  def textual_container_labels
    textual_key_value(@record.labels.to_a)
  end

  def textual_container_selectors
    textual_key_value(@record.selector_parts.to_a)
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

  def textual_key_value(items)
    items.collect { |item| {:label => item.name.to_s, :value => item.value.to_s} }.flatten.compact
  end

  def textual_link(target, **opts, &blk)
    case target
    when ActiveRecord::Relation
      textual_collection_link(target, **opts, &blk)
    else
      textual_object_link(target, **opts, &blk)
    end
  end

  def textual_object_link(object, as: nil, controller: nil, feature: nil)
    return if object.nil?

    klass = as || object.class.base_model

    controller ||= klass.name.underscore
    feature ||= "#{controller}_show"

    label = ui_lookup(:model => klass.name)
    image = textual_object_icon(object)
    value = if block_given?
              yield object
            else
              object.name
            end

    h = {:label => label, :image => image, :value => value}

    if role_allows(:feature => feature)
      h[:link] = url_for(:controller => controller,
                         :action     => 'show',
                         :id         => object)
      h[:title] = "Show #{label} '#{value}'"
    end

    h
  end

  def textual_collection_link(collection, as: nil, controller: nil, feature: nil)
    klass = as || collection.klass.base_model

    controller ||= klass.name.underscore
    feature ||= "#{controller}_show_list"

    label = ui_lookup(:models => klass.name)
    image = textual_collection_icon(collection)
    count = collection.count

    h = {:label => label, :image => image, :value => count.to_s}

    if count > 0 && role_allows(:feature => feature)
      if collection.respond_to?(:proxy_association)
        h[:link] = url_for(:action  => 'show',
                           :id      => collection.proxy_association.owner,
                           :display => collection.proxy_association.reflection.name)
      else
        h[:link] = url_for(:controller => controller,
                           :action     => 'list')
      end
      h[:title] = "Show all #{label}"
    end

    h
  end

  def textual_object_icon(object)
    case object
    when ExtManagementSystem
      "vendor-#{object.image_name}"
    else
      object.class.base_model.name.underscore
    end
  end

  def textual_collection_icon(collection)
    collection.klass.base_model.name.underscore
  end
end
