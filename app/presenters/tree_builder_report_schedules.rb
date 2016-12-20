class TreeBuilderReportSchedules < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {
      :leaf     => 'Schedules',
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("All Schedules"), t, '100/miq_schedule.png']
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    objects = if User.current_user.current_group.miq_user_role.name.split('-').last == 'super_administrator'
                # Super admins see all report schedules
                MiqSchedule.where(:towhat => 'MiqReport')
              else
                MiqSchedule.where(:towhat => 'MiqReport', :userid => User.current_user.userid)
              end
    count_only_or_objects(count_only, objects.sort_by { |o| o.name.downcase }, 'name')
  end
end
