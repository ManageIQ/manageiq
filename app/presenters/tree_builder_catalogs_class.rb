class TreeBuilderCatalogsClass < TreeBuilder
  has_kids_for CustomButtonSet, [:x_get_tree_aset_kids]

  private

  def x_get_tree_roots(count_only, options)
    objects = Rbac.filtered(ServiceTemplateCatalog.all).sort_by { |o| o.name.downcase }
    case options[:type]
    when :stcat
      return count_only_or_objects(count_only, objects)
    when :sandt
      return count_only_or_objects(count_only,
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

  def get_tree_aset_kids_for_nil_id(object, count_only)
    count_only ? get_custom_buttons(object).count : get_custom_buttons(object).sort_by { |a| a.name.downcase }
  end

  def button_order?(object)
    object[:set_data] && object[:set_data][:button_order]
  end

  def x_get_tree_aset_kids(object, count_only)
    if object.id.nil?
      get_tree_aset_kids_for_nil_id(object, count_only)
    elsif count_only
      object.members.count
    else
      button_order = button_order?(object) ? object[:set_data][:button_order] : nil
      Array(button_order).each_with_object([]) do |bidx, arr|
        object.members.each { |b| arr.push(b) if bidx == b.id && !arr.include?(b) }
      end
    end
  end
end
