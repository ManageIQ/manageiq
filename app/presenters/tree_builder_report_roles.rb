class TreeBuilderReportRoles < TreeBuilder
  private

  def tree_init_options(tree_name)
    {
      :leaf     => 'Roles',
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => 'roles_',
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    user = User.current_user
    if user.super_admin_user?
      roles = MiqGroup.all
    else
      roles = [MiqGroup.find_by_id(user.miq_group_id)]
    end
    count_only_or_objects(options[:count_only], roles.sort_by { |o| o.name.downcase }, 'name')
  end
end
