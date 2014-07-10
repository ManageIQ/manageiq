class TreeBuilderCatalogItems < TreeBuilderCatalogsClass
  private

  def tree_init_options(tree_name)
    {:full_ids => true, :leaf => 'ServiceTemplateCatalog'}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'sandt_',
      :autoload  => 'true'
    )
  end

  def x_get_tree_stc_kids(object, options)
    return count_only_or_objects(options[:count_only],
                                 rbac_filtered_objects(object.service_templates),
                                 'name') unless object.id.nil?
    objects = []
    items = rbac_filtered_objects(ServiceTemplate.find(:all))
    items.sort_by { |o| o.name.downcase }.each do |item|
      objects.push(item) if item.service_template_catalog_id.nil?
    end
    count_only_or_objects(options[:count_only], objects, 'name')
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, options)
    # build node showing any button groups or buttons under selected CatalogItem
    @resolve ||= {}
    @resolve[:target_classes] = {}
    CustomButton.button_classes.each { |db| @resolve[:target_classes][db] = ui_lookup(:model => db) }
    @sb[:target_classes] = @resolve[:target_classes].invert
    @resolve[:target_classes] = Array(@resolve[:target_classes].invert).sort
    st = ServiceTemplate.find_by_id(object[:id])
    items = st.custom_button_sets + st.custom_buttons
    objects = []
    if st.options && st.options[:button_order]
      st.options[:button_order].each do |item_id|
        items.each do |g|
          rec_id = "#{g.kind_of?(CustomButton) ? 'cb' : 'cbg'}-#{g.id}"
          objects.push(g) if item_id == rec_id
        end
      end
    end
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_st_kids(object, options)
    count = options[:type] == :svvcat ? 0 : object.custom_button_sets.count + object.custom_buttons.count
    objects = count > 0 ? [{:id => object.id.to_s, :text => 'Actions', :image => 'folder', :tip => 'Actions'}] : []
    count_only_or_objects(options[:count_only], objects, nil)
  end
end
