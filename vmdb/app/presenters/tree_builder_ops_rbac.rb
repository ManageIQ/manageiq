class TreeBuilderOpsRbac < TreeBuilder
  private

  def tree_init_options(tree_name)
    {
      :open_all   => true,
      :leaf       => "Access Control"
     }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
        :id_prefix      => "rbac_",
        :autoload       => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    [
      {:id => "u", :text => "Users", :image => "user", :tip => "Users"},
      {:id => "g", :text => "Groups", :image => "group", :tip => "Groups"},
      {:id => "ur", :text => "Roles", :image => "miq_user_role", :tip => "Roles"}
    ]
  end

  def x_get_tree_custom_kids(object_hash, options)
    objects =
        case object_hash[:id]
        when "u"  then User.in_my_region.all
        when "g"  then MiqGroup.all
        when "ur" then MiqUserRole.all
        end
    count_only_or_objects(options[:count_only], objects, "name")
  end
end
