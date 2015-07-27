module ContainerSummaryHelper
  def textual_ems
    textual_link(@record.ext_management_system, :as => EmsContainer)
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

  private

  def textual_link(target, **opts, &blk)
    case target
    when ActiveRecord::Relation
      textual_collection_link(target, **opts, &blk)
    else
      textual_object_link(target, **opts, &blk)
    end
  end

  def textual_object_link(object, as: nil, feature: nil)
    return if object.nil?

    klass = as || object.class.base_model

    feature ||= "#{klass.name.underscore}_show"

    label = ui_lookup(:class => klass.name)
    image = textual_object_icon(object)
    value = if block_given?
              yield object
            else
              object.name
            end

    h = {:label => label, :image => image, :value => value}

    if role_allows(:feature => feature)
      h[:link] = url_for(:controller => klass.name.underscore,
                         :action     => 'show',
                         :id         => object)
      h[:title] = "Show #{label} '#{value}'"
    end

    h
  end

  def textual_collection_link(collection, as: nil, feature: nil)
    klass = as || collection.klass.base_model

    feature ||= "#{klass.name.underscore}_show_list"

    label = ui_lookup(:classes => klass.name)
    image = textual_collection_icon(collection)
    count = collection.count

    h = {:label => label, :image => image, :value => count.to_s}

    if count > 0 && role_allows(:feature => feature)
      if collection.respond_to?(:proxy_association)
        h[:link] = url_for(:action  => 'show',
                           :id      => collection.proxy_association.owner,
                           :display => collection.proxy_association.reflection.name)
      else
        h[:link] = url_for(:controller => klass.name.underscore,
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
