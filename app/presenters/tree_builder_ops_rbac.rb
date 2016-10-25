class TreeBuilderOpsRbac < TreeBuilder
  has_kids_for Tenant, [:x_get_tree_tenant_kids]

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
    locals.merge!(:autoload => true)
  end

  def root_options
    region = MiqRegion.my_region
    title =  _("%{product} Region: %{region_description} [%{region}]") % {:region_description => region.description,
                                                                          :region             => region.region,
                                                                          :product            => I18n.t('product.name')}
    [title, title, :miq_region]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(_count_only, _options)
    objects = []
    if ApplicationHelper.role_allows?(:feature => "rbac_user_view", :any => true)
      objects.push(:id => "u", :text => _("Users"), :image => "user", :tip => _("Users"))
    end
    if ApplicationHelper.role_allows?(:feature => "rbac_group_view", :any => true)
      objects.push(:id => "g", :text => _("Groups"), :image => "group", :tip => _("Groups"))
    end
    if ApplicationHelper.role_allows?(:feature => "rbac_role_view", :any => true)
      objects.push(:id => "ur", :text => _("Roles"), :image => "miq_user_role", :tip => _("Roles"))
    end
    if ApplicationHelper.role_allows?(:feature => "rbac_tenant_view", :any => true)
      objects.push(:id => "tn", :text => _("Tenants"), :image => "tenant", :tip => _("Tenants"))
    end
    objects
  end

  def x_get_tree_custom_kids(object_hash, count_only, _options)
    objects =
      case object_hash[:id]
      when "u"  then Rbac.filtered(User.in_my_region)
      when "g"  then Rbac.filtered(MiqGroup.non_tenant_groups_in_my_region)
      when "ur" then MiqUserRole.all
      when "tn" then Tenant.with_current_tenant
      end
    count_only_or_objects(count_only, objects, "name")
  end

  def x_get_tree_tenant_kids(object, count_only)
    count_only_or_objects(count_only, object.children, "name")
  end
end
