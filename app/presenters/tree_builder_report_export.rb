class TreeBuilderReportExport < TreeBuilder
  private

  def tree_init_options(tree_name)
    {
      :leaf     => 'Export',
      :full_ids => true,
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
  def x_get_tree_roots(count_only, _options)
    export_children = [
      {:id    => 'exportcustomreports',
       :text  => 'Custom Reports',
       :image => 'report'},
      {:id    => 'exportwidgets',
       :text  => 'Widgets',
       :image => 'report'}
    ]
    count_only_or_objects(count_only, export_children, nil)
  end
end
