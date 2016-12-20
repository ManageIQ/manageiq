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
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("Import / Export"), t, '100/report.png']
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    export_children = [
      {:id    => 'exportcustomreports',
       :text  => _('Custom Reports'),
       :image => 'report'},
      {:id    => 'exportwidgets',
       :text  => _('Widgets'),
       :image => 'report'}
    ]
    count_only_or_objects(count_only, export_children)
  end
end
