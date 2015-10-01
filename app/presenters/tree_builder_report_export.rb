class TreeBuilderReportExport < TreeBuilder
  private

  def tree_init_options(tree_name)
    {
      :leaf     => 'Export',
      :full_ids => true,
      :add_root => nil,
      :open_all => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'export_',
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    export_children = [
      {:id => 'exportcustomreports', :tree => 'export_tree', :text => 'Custom Reports', :image => 'report'},
      {:id => 'exportwidgets', :tree => 'export_tree', :text => 'Widgets', :image => 'report'}
    ]
    count_only_or_objects(options[:count_only], export_children, nil)
  end
end
