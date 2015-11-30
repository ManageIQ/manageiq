class TreeBuilderReportSavedReports < TreeBuilderReportReportsClass
  private

  def tree_init_options(tree_name)
    {
      :full_ids => true,
      :leaf     => 'MiqReportResult'
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'savedreports_',
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    folder_ids = {}
    u = User.current_user
    g = u.admin_user? ? nil : u.miq_group
    MiqReport.having_report_results(:miq_group => g, :select => [:id, :name]).each do |r|
      folder_ids[r.name] = to_cid(r.id.to_i)
    end
    objects = []
    folder_ids.sort.each_with_index do |p|
      objects.push(:id => p[1], :text => p[0], :image => 'report', :tip => p[0])
    end
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    objects = MiqReportResult.where(set_saved_reports_condition(from_cid(object[:id].split('-').last))).all
    count_only_or_objects(count_only, objects, nil)
  end
end
