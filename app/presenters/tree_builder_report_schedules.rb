class TreeBuilderReportSchedules < TreeBuilder
  private

  def tree_init_options(tree_name)
    {
      :leaf     => 'Schedules',
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'schedules_',
      :autoload  => true
    )
  end

  def root_options
    [t = _("All Schedules"), t, :miq_schedule]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    if User.current_user.current_group.miq_user_role.name.split('-').last == 'super_administrator'
      # Super admins see all report schedules
      objects = MiqSchedule.where(:towhat => 'MiqReport')
    else
      objects = MiqSchedule.where(:towhat => 'MiqReport', :userid => User.current_user.userid)
    end
    count_only_or_objects(count_only, objects.sort_by { |o| o.name.downcase }, 'name')
  end
end
