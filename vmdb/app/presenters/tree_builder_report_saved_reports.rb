class TreeBuilderReportSavedReports < TreeBuilder

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

  def x_get_tree_r_kids(object, options)
    # view = get_view(MiqReportResult, :where_clause=>set_saved_reports_condition(object.id), :all_pages=>true)
    objects = MiqReportResult.where(set_saved_reports_condition(object.id)).all

    # saved_reps = view.table.data
    # objects = Array.new
    # saved_reps.each do |s|
    #  objects.push(MiqReportResult.find_by_id(s["id"]))
    # end
    # if options[:count_only]
    #  return objects.count
    # else
    #  return (objects.sort{|a,b| a.name.downcase <=> b.name.downcase})
    # end
    count_only_or_objects(options[:count_only], objects, nil)
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    # Saving the unique folder id's that hold reports under them, to use them in view to generate link
    @sb[:folder_ids] = {}
    u = User.current_user
    g = u.admin_user? ? nil : u.miq_group.miq_user_role.name.split('-').last
    MiqReport.having_report_results(:miq_group => g, :select => [:id, :name]).each do |r|
      @sb[:folder_ids][r.name] = to_cid(r.id.to_i)
    end
    objects = []
    @sb[:folder_ids].sort.each_with_index do |p|
      objects.push({:id => p[1], :text => p[0], :image => 'report', :tip => p[0]})
    end
    count_only_or_objects(options[:count_only], objects, nil)
  end

  # Saving the unique folder id's that hold reports under them, to use them in view to generate link
#  @sb[:folder_ids] = Hash.new
#  u = User.find_by_userid(session[:userid])
#  g = u.admin_user? ? nil : session[:group]
#  MiqReport.having_report_results(:miq_group => g, :select => [:id, :name]).each do |r|
#    @sb[:folder_ids][r.name] = to_cid(r.id.to_i)
#  end
#  objects = Array.new
#  @sb[:folder_ids].sort.each_with_index do |p,i|
#    objects.push({:id=>p[1], :text=>p[0], :image=>"report", :tip=>p[0]})
#  end
#  return objects

  def x_get_tree_custom_kids(object, options)
    # view = get_view(MiqReportResult, :where_clause => set_saved_reports_condition(from_cid(object[:id].split('-').last)),
    #                                                                               :all_pages => true)
    # objects = []
    # #view.table.data.each do |s|
    # view.each do |s|
    #   objects.push(MiqReportResult.find_by_id(s['id']))
    # end
    objects = MiqReportResult.where(set_saved_reports_condition(from_cid(object[:id].split('-').last))).all
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def set_saved_reports_condition(rep_id=nil)
    u = User.current_user
    cond = []

    # Replaced this code as all saved, requested, scheduled reports have miq_report_id set, others don't
    #cond[0] = "(report_source=? OR report_source=? OR report_source=?)"
    #cond.push("Saved by user")
    #cond.push("Requested by user")
    #cond.push("Scheduled")

    if rep_id.nil?
      cond[0] = "miq_report_id IS NOT NULL"
    else
      cond[0] = "miq_report_id=?"
      cond.push(rep_id)
    end

    # Admin users can see all saved reports
    unless u.admin_user?
      cond[0] << " AND miq_group_id=?"
      cond.push(session[:group])
    end

    cond.flatten
  end
end
