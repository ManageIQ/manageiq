class TreeBuilderReportReportsClass < TreeBuilder
  has_kids_for MiqReport, [:x_get_tree_r_kids]

  private

  def x_get_tree_r_kids(object, count_only)
    scope = MiqReportResult.with_current_user_groups_and_report(object.id)
    count_only ? scope.size : scope.order("last_run_on DESC").to_a
  end
end
