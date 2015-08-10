module TextualHelper
  def textual_link(target, **opts, &blk)
    case target
    when ActiveRecord::Relation
      textual_collection_link(target, **opts, &blk)
    else
      textual_object_link(target, **opts, &blk)
    end
  end

  private

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
