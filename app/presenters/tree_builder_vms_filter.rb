class TreeBuilderVmsFilter < TreeBuilder
  def tree_init_options(_tree_name)
    {
      :open_all => true,
      :leaf     => 'Vm'
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id   => "vms_filter_treebox",
      :tree_name => "vms_filter_tree",
      :id_prefix => "vf_",
    )
  end

  def x_get_tree_roots(options)
    objects =
      [
        {:id => "global", :text => _("Global Filters"), :image => "folder", :tip => _("Global Shared Filters"), :cfmeNoClick => true},
        {:id => "my",     :text => _("My Filters"),     :image => "folder", :tip => _("My Personal Filters"),   :cfmeNoClick => true}
      ]
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_custom_kids(object, options)
    objects = MiqSearch.where(:db => options[:leaf])
    objects = case object[:id]
              when "global" # Global filters
                objects.where("search_type=? or (search_type=? and (search_key is null or search_key<>?))", "global", "default", "_hidden_")
              when "my"     # My filters
                objects.where(:search_type => "user", :search_key => User.current_user.userid)
              end
    count_only_or_objects(options[:count_only], objects, 'description')
  end
end
