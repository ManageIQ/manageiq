class TreeBuilderButtons < TreeBuilderAeCustomization
  has_kids_for CustomButtonSet, [:x_get_tree_aset_kids]

  private

  def tree_init_options(_tree_name)
    {:leaf => "CustomButton", :open_all => true, :full_ids => true}
  end

  def root_options
    [t = _("Object Types"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(_count_only, _options)
    resolve = {}
    CustomButton.button_classes.each { |db| resolve[db] = ui_lookup(:model => db) }
    @sb[:target_classes] = resolve.invert
    resolve = Array(resolve.invert).sort
    resolve.collect do |typ|
      {:id => "ab_#{typ[1]}", :text => typ[0], :image => buttons_node_image(typ[1]), :tip => typ[0]}
    end
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    nodes = object[:id].split('_')
    objects = CustomButtonSet.find_all_by_class_name(nodes[1])
    # add as first element of array
    objects.unshift(
      CustomButtonSet.new(:name => "[Unassigned Buttons]|ub-#{nodes[1]}", :description => "[Unassigned Buttons]")
    )
    count_only_or_objects(count_only, objects)
  end

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
      # need to show button nodes in button order that they were saved in
      button_order = button_order?(object) ? object[:set_data][:button_order] : nil
      objects = []
      Array(button_order).each do |bidx|
        object.members.each { |b| objects.push(b) if bidx == b.id && !objects.include?(b) }
      end
      objects
    end
  end

  def buttons_node_image(node)
    case node
    when "ExtManagementSystem" then '100/ext_management_system.png'
    when "MiqTemplate"         then '100/vm.png'
    when 'CloudTenant'         then '100/cloud_tenant.png'
    else                            "100/#{node.downcase}.png"
    end
  end
end
