class TreeBuilderReportReportsClass < TreeBuilder
  private

  def x_get_tree_r_kids(object, count_only)
    objects = MiqReportResult.where(set_saved_reports_condition(object.id)).to_a
    count_only_or_objects(count_only, objects, nil)
  end

  def set_saved_reports_condition(rep_id = nil)
    u = User.current_user
    cond = []

    if rep_id.nil?
      cond[0] = 'miq_report_id IS NOT NULL'
    else
      cond[0] = 'miq_report_id=?'
      cond.push(rep_id)
    end

    # Admin users can see all saved reports
    unless u.admin_user?
      cond[0] << ' AND miq_group_id=?'
      cond.push(u.current_group_id)
    end

    cond.flatten
  end
end
