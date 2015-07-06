class TreeBuilderPxeCustomizationTemplates < TreeBuilder

  private

  def tree_init_options(tree_name)
    {:leaf => "CustomizationTemplate"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "ct_",
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    items = PxeImageType.all
    if options[:count_only]
      # add +1 for customization spec folder thats used to show system templates
      items.length + 1
    else
      objects = []
      objects.push({:id => "xx-system", :text => "Examples (read only)", :image => "folder", :tip => "Examples (read only)"})
      PxeImageType.all.sort.each do |item, idx|
        objects.push({:id => "xx-#{to_cid(item.id)}", :text => item.name, :image => "folder", :tip => item.name})
      end
      objects
    end
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, options)
    nodes = object[:full_id] ? object[:full_id].split('-') : object[:id].split('-')
    if nodes[1] == "system" || nodes[2] == "system"
      # root node was clicked or if folder node was clicked
      #System templates
      objects = CustomizationTemplate.find_all_by_pxe_image_type_id(nil)
    else
      # root node was clicked or if folder node was clicked
      id =  nodes.length >= 3 ? nodes[2] : nodes[1]
      pxe_img = PxeImageType.find_by_id(from_cid(id))
      objects = CustomizationTemplate.find_all_by_pxe_image_type_id(pxe_img.id)
    end
    count_only_or_objects(options[:count_only], objects, "name")
  end
end
