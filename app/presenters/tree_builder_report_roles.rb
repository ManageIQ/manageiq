class TreeBuilderReportRoles < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {
      :leaf     => 'Roles',
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    user = User.current_user
    title = if user.super_admin_user?
              _("All %{models}") % {:models => ui_lookup(:models => "MiqGroup")}
            else
              _("My %{models}") % {:models => ui_lookup(:models => "MiqGroup")}
            end
    [title, title, '100/miq_group.png']
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    user  = User.current_user
    roles = user.super_admin_user? ? MiqGroup.non_tenant_groups_in_my_region : [user.current_group]
    count_only_or_objects(count_only, roles.sort_by { |o| o.name.downcase }, 'name')
  end
end
