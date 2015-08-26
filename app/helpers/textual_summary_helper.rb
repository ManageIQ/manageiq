module TextualSummaryHelper
  def textual_link(target, **opts, &blk)
    case target
    when ActiveRecord::Relation, Array
      textual_collection_link(target, **opts, &blk)
    else
      textual_object_link(target, **opts, &blk)
    end
  end

  def expand_textual_summary(summary)
    case summary
    when Hash
      summary
    when Symbol
      send("textual_#{summary}")
    when nil
      nil
    else
      raise "Unexpected summary type: #{summary.class}"
    end
  end

  def expand_textual_group(summaries)
    Array.wrap(summaries).map { |summary| expand_textual_summary(summary) }.compact
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h = {:label => label}
    tags = session[:assigned_filters]
    if tags.blank?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, _assigned| category.downcase }
                  .collect do |category, assigned|
                    {:image => "smarttag",
                     :label => category,
                     :value => assigned}
                  end
    end
    h
  end

  private

  def textual_object_link(object, as: nil, controller: nil, feature: nil)
    return if object.nil?

    klass = as || object.class.base_model

    controller ||= klass.name.underscore
    feature ||= "#{controller}_show"

    label = ui_lookup(:model => klass.name)
    image = textual_object_icon(object, klass)
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

  def textual_collection_link(collection, as: nil, controller: nil, explorer: false, feature: nil, link: nil)
    if collection.kind_of?(Array)
      unless as && link
        raise ArgumentError, ":as and :link are both required when linking to an array",
              caller.reject { |x| x =~ /^#{__FILE__}:/ }
      end
    end

    klass = as || collection.klass.base_model

    controller ||= klass.name.underscore
    feature ||= "#{controller}_show_list"

    label = ui_lookup(:models => klass.name)
    image = textual_collection_icon(collection, klass)
    count = collection.count

    h = {:label => label, :image => image, :value => count.to_s}

    if count > 0 && role_allows(:feature => feature)
      if link
        h[:link] = link
      elsif collection.respond_to?(:proxy_association)
        h[:link] = url_for(:action  => 'show',
                           :id      => collection.proxy_association.owner,
                           :display => collection.proxy_association.reflection.name)
      else
        h[:link] = url_for(:controller => controller,
                           :action     => 'list')
      end
      h[:title] = "Show all #{label}"
      h[:explorer] = true if explorer
    end

    h
  end

  def textual_object_icon(object, klass)
    case object
    when ExtManagementSystem
      "vendor-#{object.image_name}"
    else
      textual_class_icon(klass)
    end
  end

  def textual_collection_icon(_collection, klass)
    textual_class_icon(klass)
  end

  def textual_class_icon(klass)
    if klass <= AdvancedSetting
      "advancedsetting"
    elsif klass <= MiqTemplate
      "vm"
    else
      klass.name.underscore
    end
  end
end
