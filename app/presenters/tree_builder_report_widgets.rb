class TreeBuilderReportWidgets < TreeBuilder
  private

  def tree_init_options(tree_name)
    {:leaf => 'Widgets', :full_ids => true}
  end

  def set_locals_for_render
    super.merge!(:autoload => true)
  end

  def root_options
    [t = _("All Widgets"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = WIDGET_TYPES.collect { |k, v| {:id => k, :text => _(v), :image => '100/folder.png', :tip => _(v)} }
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    widgets = MiqWidget.where(:content_type => WIDGET_CONTENT_TYPE[object[:id].split('-').last])
    count_only_or_objects(count_only, widgets, 'title')
  end
end
