class TreeBuilderUtilization < TreeBuilderRegion
  has_kids_for ExtManagementSystem, [:x_get_tree_ems_kids]
  has_kids_for Datacenter, [:x_get_tree_datacenter_kids, :type]
  has_kids_for EmsFolder, [:x_get_tree_folder_kids, :type]
  has_kids_for EmsCluster, [:x_get_tree_cluster_kids]

  private

  def x_get_tree_ems_kids(object, count_only)
    ems_clusters        = rbac_filtered_objects(object.ems_clusters)
    non_clustered_hosts = rbac_filtered_objects(object.non_clustered_hosts)

    total = ems_clusters.count + non_clustered_hosts.count

    return total if count_only
    return [] if total == 0

    [
      {
        :id    => "folder_c_xx-#{to_cid(object.id)}",
        :text  => _("Cluster / Deployment Role"),
        :image => "folder",
        :tip   => _("Cluster / Deployment Role (Click to open)")
      }
    ]
  end

  def x_get_tree_datacenter_kids(object, count_only, type)
    objects =
      case type
      when :vandt then x_get_tree_vandt_datacenter_kids(object)
      when :handc then x_get_tree_handc_datacenter_kids(object)
      end
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_vandt_datacenter_kids(object)
    # Count clusters directly in this folder
    objects = rbac_filtered_sorted_objects(object.clusters, "name", :match_via_descendants => VmOrTemplate)
    object.folders.each do |f|
      if f.name == "vm"                 # Count vm folder children
        objects += rbac_filtered_sorted_objects(f.folders, "name", :match_via_descendants => VmOrTemplate)
        objects += rbac_filtered_sorted_objects(f.vms_and_templates, "name")
      elsif f.name == "host"            # Don't count host folder children
      else                              # add in other folders
        objects += rbac_filtered_objects([f], :match_via_descendants => VmOrTemplate)
      end
    end
  end

  def x_get_tree_handc_datacenter_kids(object)
    objects = rbac_filtered_sorted_objects(object.clusters, "name")
    object.folders.each do |f|
      if f.name == "vm"                 # Don't add vm folder children
      elsif f.name == "host"            # Add host folder children
        objects += rbac_filtered_sorted_objects(f.folders, "name")
        objects += rbac_filtered_sorted_objects(f.clusters, "name")
        objects += rbac_filtered_sorted_objects(f.hosts, "name")
      else                              # add in other folders
        objects += rbac_filtered_objects([f])
      end
    end
  end

  def x_get_tree_folder_kids(object, count_only, type)
    objects = []
    case type
    when :vandt, :handc, :storage_pod
      objects =  rbac_filtered_sorted_objects(object.folders_only, "name", :match_via_descendants => VmOrTemplate)
      objects += rbac_filtered_sorted_objects(object.datacenters_only, "name", :match_via_descendants => VmOrTemplate)
      objects += rbac_filtered_sorted_objects(object.clusters, "name", :match_via_descendants => VmOrTemplate)
      objects += rbac_filtered_sorted_objects(object.hosts, "name", :match_via_descendants => VmOrTemplate)
      objects += rbac_filtered_sorted_objects(object.vms_and_templates, "name")
    end
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_cluster_kids(object, count_only)
    objects =  rbac_filtered_sorted_objects(object.hosts, "name")
    # FIXME: is the condition below ever false?
    unless [:bottlenecks, :utilization].include?(@type)
      objects += rbac_filtered_sorted_objects(object.resource_pools, "name")
      objects += rbac_filtered_sorted_objects(object.vms, "name")
    end
    count_only_or_objects(count_only, objects, nil)
  end
end
