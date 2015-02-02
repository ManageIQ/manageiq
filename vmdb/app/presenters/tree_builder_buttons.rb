class TreeBuilderButtons  < TreeBuilderAeCustomization
  private

  def tree_init_options(tree_name)
    {:leaf => "CustomButton", :open_all => true, :full_ids => true }
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    resolve = Hash.new
    CustomButton.button_classes.each{|db| resolve[db] = ui_lookup(:model=>db)}
    @sb[:target_classes] = resolve.invert
    resolve = Array(resolve.invert).sort
    resolve.collect { |typ| {:id => "ab_#{typ[1]}", :text => typ[0], :image => buttons_node_image(typ[1]), :tip => typ[0]} }
  end

  def x_get_tree_custom_kids(object, options)
    nodes = object[:id].split('_')
    objects = CustomButtonSet.find_all_by_class_name(nodes[1])
    #add as first element of array
    objects.unshift(CustomButtonSet.new(:name => "[Unassigned Buttons]|ub-#{nodes[1]}", :description => "[Unassigned Buttons]"))
    count_only_or_objects(options[:count_only], objects, nil)
  end

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
        #need to show button nodes in button order that they were saved in
        button_order = object[:set_data] && object[:set_data][:button_order] ? object[:set_data][:button_order] : nil
        objects = []
        Array(button_order).each do |bidx|
          object.members.each { |b| objects.push(b) if bidx == b.id && !objects.include?(b) }
        end
        objects
      end
    end
  end

  def buttons_node_image(node)
    case node
    when "ExtManagementSystem" then "ext_management_system"
    when "MiqTemplate"         then "vm"
    else                            node.downcase
    end
  end
end
