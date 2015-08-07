class TreeBuilderReportDashboards < TreeBuilder
  private

  def tree_init_options(tree_name)
    {
      :leaf     => 'Dashboards',
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'dashboards_',
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    objects = []
    default_ws = MiqWidgetSet.find_by_name_and_read_only('default', true)
    text = "#{default_ws.description} (#{default_ws.name})"
    objects.push(:id => to_cid(default_ws.id), :text => text, :image => 'dashboard', :tip => text)
    objects.push(:id => 'g', :text => 'All Groups', :image => 'folder', :tip => 'All Groups')
    count_only_or_objects(options[:count_only], objects, nil)
  end
end
