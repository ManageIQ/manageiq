class TreeBuilderInstances < TreeBuilder
  def tree_init_options(_tree_name)
    {
      :leaf => 'VmCloud'
    }
  end

  def x_get_tree_roots(options)
    objects = rbac_filtered_objects(EmsCloud.order("lower(name)"), :match_via_descendants => "VmCloud")
    objects += [
      {:id => "arch", :text => _("<Archived>"), :image => "currentstate-archived", :tip => _("Archived Instances")},
      {:id => "orph", :text => _("<Orphaned>"), :image => "currentstate-orphaned", :tip => _("Orphaned Instances")}
    ]
    count_only_or_objects(options[:count_only], objects, nil)
  end

  include TreeBuilderCommon
  include TreeBuilderArchived
end
