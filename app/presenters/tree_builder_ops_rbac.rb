class TreeBuilderOpsRbac < TreeBuilder
  private

  def tree_init_options(_tree_name)
    {
      :open_all => true,
      :leaf     => "Access Control",
      :expand   => false
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "rbac_",
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(_count_only, _options)
    objects = []
    if ApplicationHelper.role_allows(:feature => "rbac_user_view", :any => true)
      objects.push(:id => "u", :text => _("Users"), :image => "user", :tip => _("Users"))
    end
    if ApplicationHelper.role_allows(:feature => "rbac_group_view", :any => true)
      objects.push(:id => "g", :text => _("Groups"), :image => "group", :tip => _("Groups"))
    end
    if ApplicationHelper.role_allows(:feature => "rbac_role_view", :any => true)
      objects.push(:id => "ur", :text => _("Roles"), :image => "miq_user_role", :tip => _("Roles"))
    end
    if ApplicationHelper.role_allows(:feature => "rbac_tenant_view", :any => true)
      objects.push(:id => "tn", :text => _("Tenants"), :image => "tenant", :tip => _("Tenants"))
    end
    objects
  end

  def x_get_tree_custom_kids(object_hash, count_only, _options)
    objects =
      case object_hash[:id]
      when "u"  then rbac_filtered_objects(User.in_my_region)
      when "g"  then rbac_filtered_objects(MiqGroup.non_tenant_groups_in_my_region)
      when "ur" then MiqUserRole.all
      when "tn" then Tenant.with_current_tenant
      end
    count_only_or_objects(count_only, objects, "name")
  end

  def x_get_tree_tenant_kids(object, count_only)
    count_only_or_objects(count_only, object.children, "name")
  end
end
