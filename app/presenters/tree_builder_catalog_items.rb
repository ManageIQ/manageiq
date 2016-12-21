class TreeBuilderCatalogItems < TreeBuilderCatalogsClass
  has_kids_for ServiceTemplateCatalog, [:x_get_tree_stc_kids]
  has_kids_for ServiceTemplate, [:x_get_tree_st_kids, :type]

  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :leaf => 'ServiceTemplateCatalog'}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => 'true')
  end

  def root_options
    [t = _("All Catalog Items"), t]
  end

  def x_get_tree_stc_kids(object, count_only)
    # TODO: may want to order in rbac and not in sql
    templates = if object.id.nil?
                  ServiceTemplate.where(:service_template_catalog_id => nil).order("lower(name)")
                else
                  object.service_templates
                end
    count_only_or_objects(count_only, Rbac.filtered(templates), 'name')
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, count_only, _options)
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
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_st_kids(object, count_only, type)
    count = type == :svvcat ? 0 : object.custom_button_sets.count + object.custom_buttons.count
    objects = count > 0 ? [{:id => object.id.to_s, :text => 'Actions', :image => '100/folder.png', :tip => 'Actions'}] : []
    count_only_or_objects(count_only, objects)
  end
end
