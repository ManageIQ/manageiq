class TreeBuilderInstances < TreeBuilder
  has_kids_for AvailabilityZone, [:x_get_tree_az_kids]
  has_kids_for ExtManagementSystem, [:x_get_tree_ems_kids]

  include TreeBuilderArchived

  def tree_init_options(_tree_name)
    {
      :leaf => 'VmCloud',
      :lazy => false
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id   => "instances_treebox",
      :tree_name => "instances_tree",
      :autoload  => true,
      :allow_reselect => TreeBuilder.hide_vms
    )
  end

  def root_options
    [_("Instances by Provider"), _("All Instances by Provider that I can see")]
  end

  def x_get_tree_roots(count_only, _options)
    count_only_or_objects_filtered(count_only, EmsCloud, "name", :match_via_descendants => VmCloud) +
      count_only_or_objects(count_only, x_get_tree_arch_orph_nodes("Instances"))
  end

  def x_get_tree_ems_kids(object, count_only)
    count_only_or_objects_filtered(count_only, object.availability_zones, "name") +
      count_only_or_objects_filtered(count_only,
                                     TreeBuilder.hide_vms ? [] : object.vms.where(:availability_zone_id => nil),
                                     "name")
  end

  # Get AvailabilityZone children count/array
  def x_get_tree_az_kids(object, count_only)
    count_only_or_objects_filtered(count_only,
                                   TreeBuilder.hide_vms ? [] : object.vms.not_archived_nor_orphaned,
                                   "name")
  end
end
