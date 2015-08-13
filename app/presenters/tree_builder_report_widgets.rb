class TreeBuilderReportWidgets < TreeBuilder
  private

  def tree_init_options(tree_name)
    {
      :leaf     => 'Widgets',
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'widgets_',
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    objects = []
    WIDGET_TYPES.keys.each do |w|
      objects.push(:id => w, :text => WIDGET_TYPES[w], :image => 'folder', :tip => WIDGET_TYPES[w])
    end
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_custom_kids(object, options)
    count_only_or_objects(options[:count_only],
                          MiqWidget.find_all_by_content_type(WIDGET_CONTENT_TYPE[object[:id].split('-').last]), 'title')
  end
end
