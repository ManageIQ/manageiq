class TreeBuilderCatalogsClass < TreeBuilder
  private

  def x_get_tree_roots(options)
    objects = rbac_filtered_objects(ServiceTemplateCatalog.all).sort_by { |o| o.name.downcase }
    case options[:type]
    when :stcat
      return count_only_or_objects(options[:count_only], objects, nil)
    when :sandt
      return count_only_or_objects(options[:count_only],
                                   objects.unshift(ServiceTemplateCatalog.new(:name        => 'Unassigned',
                                                                              :description => 'Unassigned Catalogs')),
                                   nil)
    end
  end

  # TODO: De-duplicate the following methods from tree_builder_buttons.rb
  def get_custom_buttons(object)
    # FIXME: don't we have a method for the splits?
    # FIXME: cannot we ask for the null parent using Arel?
    CustomButton.buttons_for(object.name.split('|').last.split('-').last).select do |uri|
      uri.parent.nil?
    end
  end

  def x_get_tree_aset_kids(object, options)
    if options[:count_only]
      object.id.nil? ? get_custom_buttons(object).count : object.members.count
    else
      if object.id.nil?
        get_custom_buttons(object).sort_by { |a| a.name.downcase }
      else
        # need to show button nodes in button order that they were saved in
        button_order = object[:set_data] && object[:set_data][:button_order] ? object[:set_data][:button_order] : nil
        objects = []
        Array(button_order).each do |bidx|
          object.members.each { |b| objects.push(b) if bidx == b.id && !objects.include?(b) }
        end
        objects
      end
    end
  end
end
