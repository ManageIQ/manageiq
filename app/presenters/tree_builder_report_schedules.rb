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

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    if User.current_user.current_group.miq_user_role.name.split('-').last == 'super_administrator'  # Super admins see all report schedules
      objects = MiqSchedule.all(:conditions => %w(towhat=? MiqReport))
    else
      objects = MiqSchedule.all(:conditions => ['towhat=? AND userid=?', 'MiqReport', User.current_user.userid])
    end
    count_only_or_objects(options[:count_only], objects.sort_by{ |o| o.name.downcase }, 'name')
  end
end
