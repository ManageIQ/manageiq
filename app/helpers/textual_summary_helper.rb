module TextualSummaryHelper
  def textual_link(target, **opts, &blk)
    case target
    when ActiveRecord::Relation, Array
      textual_collection_link(target, **opts, &blk)
    else
      textual_object_link(target, **opts, &blk)
    end
  end

  def expand_textual_summary(summary, context)
    case summary
    when Hash
      summary
    when Symbol
      result = send("textual_#{summary}")
      return result if result.kind_of?(Hash) && result[:label]

      automatic_label = context.class.human_attribute_name(summary, :default => summary.to_s.titleize)

      case result
      when Hash
        result.dup.tap do |h|
          h[:label] = automatic_label
        end
      when ActiveRecord::Relation, ActiveRecord::Base
        textual_link(result, :label => automatic_label)
      when String, Fixnum, true, false, nil
        {:label => automatic_label, :value => result.to_s} unless result.to_s.blank?
      end
    when nil
      nil
    else
      raise _("Unexpected summary type: %{class}") % {:class => summary.class}
    end
  end

  def expand_textual_group(summaries, context = @record)
    Array.wrap(summaries).map { |summary| expand_textual_summary(summary, context) }.compact
  end

  def tags_from_record(record)
    record.tags.each_with_object(Array.new(0)) do |tag,tags|
      values = tag.name.split('/')
      p = tags.find { |x| x[:label] == values[2].humanize }
      value = Classification.find_by(:tag_id => tag.id).description
      if p.present?
        p[:value].push(value)
      else
        name = Classification.find_by(:id => Classification.find_by(:tag_id => tag.id).parent_id).description
        tags.push(:image => "smarttag", :label => name, :value => [value])
      end
    end
  end

  def textual_tags
    label = _("%{name} Tags") % {:name => session[:customer_name]}
    tags = {:label => label}
    if @record.tags.blank?
      tags[:image] = "smarttag"
      tags[:value] = _("No %{label} have been assigned") % {:label => label}
    else
      tags[:value] = tags_from_record(@record)
      tags[:value].each { |value| value[:value].sort! }
      tags[:value].sort_by!{ |x| x[:label] }
    end
    tags
  end

  private

  def textual_object_link(object, as: nil, controller: nil, feature: nil, label: nil)
    return if object.nil?

    klass = as || ui_base_model(object.class)

    controller ||= controller_for_model(klass)
    feature ||= "#{controller}_show"

    label ||= ui_lookup(:model => klass.name)
    image = textual_object_icon(object, klass)
    value = if block_given?
              yield object
            else
              object.name
            end

    h = {:label => label, :image => image, :value => value}

    if role_allows(:feature => feature)
      if restful_routed?(object)
        h[:link] = polymorphic_path(object)
      else
        h[:link] = url_for(:controller => controller,
                           :action     => 'show',
                           :id         => object)
      end
      h[:title] = _("Show %{label} '%{value}'") % {:label => label, :value => value}
    end

    h
  end

  def textual_collection_link(collection, as: nil, controller_collection: nil, explorer: false, feature: nil, label: nil, link: nil)
    if collection.kind_of?(Array)
      unless as && link
        raise ArgumentError, _(":as and :link are both required when linking to an array"),
              caller.reject { |x| x =~ /^#{__FILE__}:/ }
      end
    end

    klass = as || ui_base_model(collection.klass)

    controller_collection ||= klass.name.underscore
    feature ||= "#{controller_collection}_show_list"

    label ||= ui_lookup(:models => klass.name)
    image = textual_collection_icon(collection, klass)
    count = collection.count

    h = {:label => label, :image => image, :value => count.to_s}

    if count > 0 && role_allows(:feature => feature)
      if link
        h[:link] = link
      elsif collection.respond_to?(:proxy_association)
        owner = collection.proxy_association.owner
        display = collection.proxy_association.reflection.name

        if restful_routed?(owner)
          h[:link] = polymorphic_path(owner, :display => display)
        else
          h[:link] = url_for(:controller => controller_for_model(owner.class),
                             :action     => 'show',
                             :id         => owner,
                             :display    => display)
        end
      else
        h[:link] = url_for(:controller => controller_collection,
                           :action     => 'list')
      end
      h[:title] = _("Show all %{label}") % {:label => label}
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

  def textual_authentications(authentications)
    return [{:label => _("Default Authentication"), :title => t = _("None"), :value => t}] if authentications.blank?

    authentications.collect do |auth|
      label = case auth[:authtype]
              when "default"     then _("Default")
              when "metrics"     then _("C & U Database")
              when "amqp"        then _("AMQP")
              when "ipmi"        then _("IPMI")
              when "remote"      then _("Remote Login")
              when "ws"          then _("Web Services")
              when "ssh_keypair" then _("SSH Key Pair")
              else;              _("<Unknown>")
              end

      {:label => _("%{label} Credentials") % {:label => label},
       :value => auth[:status] || _("None"),
       :title => auth[:status_details]}
    end
  end
end
