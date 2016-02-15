class TreeBuilderReportReportsClass < TreeBuilder
  private

  def x_get_tree_r_kids(object, count_only)
    objects = MiqReportResult.with_current_user_groups_and_report(object.id).to_a
    count_only_or_objects(count_only, objects, nil)
  end
end
