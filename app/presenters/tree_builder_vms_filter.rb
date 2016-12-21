class TreeBuilderVmsFilter < TreeBuilder
  def tree_init_options(_tree_name)
    {
      :open_all => true,
      :leaf      => 'ManageIQ::Providers::InfraManager::Vm'
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:tree_id => "vms_filter_treebox", :tree_name => "vms_filter_tree")
  end

  def root_options
    [_("All VMs"), _("All of the VMs that I can see")]
  end

  def x_get_tree_roots(count_only, _options)
    objects =
      [
        {:id => "global", :text => _("Global Filters"), :image => "100/folder.png", :tip => _("Global Shared Filters"), :cfmeNoClick => true},
        {:id => "my",     :text => _("My Filters"),     :image => "100/folder.png", :tip => _("My Personal Filters"),   :cfmeNoClick => true}
      ]
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_custom_kids(object, count_only, options)
    objects = MiqSearch.where(:db => options[:leaf])
    objects = case object[:id]
              when "global" # Global filters
                objects.visible_to_all
              when "my"     # My filters
                objects.where(:search_type => "user", :search_key => User.current_user.userid)
              end
    count_only_or_objects(count_only, objects, 'description')
  end
end
