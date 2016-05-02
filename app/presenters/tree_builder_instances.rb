class TreeBuilderInstances < TreeBuilder
  has_kids_for AvailabilityZone, [:x_get_tree_az_kids]
  has_kids_for ExtManagementSystem, [:x_get_tree_ems_kids]

  def tree_init_options(_tree_name)
    {
      :leaf => 'VmCloud'
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :tree_id   => "instances_treebox",
      :tree_name => "instances_tree",
      :id_prefix => "instances_",
      :autoload  => true
    )
  end

  def x_get_tree_roots(count_only, _options)
    objects = rbac_filtered_objects(EmsCloud.order("lower(name)"), :match_via_descendants => VmCloud)
    objects += [
      {:id => "arch", :text => _("<Archived>"), :image => "currentstate-archived", :tip => _("Archived Instances")},
      {:id => "orph", :text => _("<Orphaned>"), :image => "currentstate-orphaned", :tip => _("Orphaned Instances")}
    ]
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_ems_kids(object, count_only)
    objects = rbac_filtered_objects(object.availability_zones.order("name")) +
              rbac_filtered_objects(object.vms.where(:availability_zone_id => nil).order("name"))
    count_only ? objects.length : objects
  end

  # Get AvailabilityZone children count/array
  def x_get_tree_az_kids(object, count_only)
    objects = rbac_filtered_objects(object.vms.order("name"))
    objects = objects.reject { |obj| obj.archived? || obj.orphaned? }
    count_only ? objects.length : objects
  end

  include TreeBuilderArchived
end
