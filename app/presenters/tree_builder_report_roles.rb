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
  def x_get_tree_roots(count_only, _options)
    user  = User.current_user
    roles = user.super_admin_user? ? MiqGroup.non_tenant_groups_in_my_region : [user.current_group]
    count_only_or_objects(count_only, roles.sort_by { |o| o.name.downcase }, 'name')
  end
end
