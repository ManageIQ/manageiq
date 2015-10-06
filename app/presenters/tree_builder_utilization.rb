class TreeBuilderUtilization < TreeBuilderRegion
  private

  def x_get_tree_ems_kids(object, options)
    ems_clusters        = rbac_filtered_objects(object.ems_clusters)
    non_clustered_hosts = rbac_filtered_objects(object.non_clustered_hosts)

    total = ems_clusters.count + non_clustered_hosts.count

    return total if options[:count_only]
    return [] if total == 0

    click_to_open = _('Click to open')
    [
      {
        :id    => "folder_c_xx-#{to_cid(object.id)}",
        :text  => ui_lookup(:ems_cluster_types => "cluster"),
        :image => "folder",
        :tip   => "#{ui_lookup(:ems_cluster_types => "cluster")} (#{click_to_open})"
      }
    ]
  end

  def x_get_tree_datacenter_kids(object, options)
    objects =
      case options[:type]
      when :vandt then x_get_tree_vandt_datacenter_kids(object, options)
      when :handc then x_get_tree_handc_datacenter_kids(object, options)
      end
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_vandt_datacenter_kids(object, _options)
    # Count clusters directly in this folder
    objects = rbac_filtered_sorted_objects(object.clusters, "name", :match_via_descendants => "VmOrTemplate")
    object.folders.each do |f|
      if f.name == "vm"                 # Count vm folder children
        objects += rbac_filtered_sorted_objects(f.folders, "name", :match_via_descendants => "VmOrTemplate")
        objects += rbac_filtered_sorted_objects(f.vms_and_templates, "name")
      elsif f.name == "host"            # Don't count host folder children
      else                              # add in other folders
        objects += rbac_filtered_objects([f], :match_via_descendants => "VmOrTemplate")
      end
    end
  end

  def x_get_tree_handc_datacenter_kids(object, _options)
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

  def x_get_tree_folder_kids(object, options)
    objects = []
    case options[:type]
    when :vandt, :handc
      objects =  rbac_filtered_sorted_objects(object.folders_only, "name", :match_via_descendants => "VmOrTemplate")
      objects += rbac_filtered_sorted_objects(object.datacenters_only, "name", :match_via_descendants => "VmOrTemplate")
      objects += rbac_filtered_sorted_objects(object.clusters, "name", :match_via_descendants => "VmOrTemplate")
      objects += rbac_filtered_sorted_objects(object.hosts, "name", :match_via_descendants => "VmOrTemplate")
      objects += rbac_filtered_sorted_objects(object.vms_and_templates, "name")
    end
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_cluster_kids(object, options)
    objects =  rbac_filtered_sorted_objects(object.hosts, "name")
    # FIXME: is the condition below ever false?
    unless [:bottlenecks, :utilization].include?(@type)
      objects += rbac_filtered_sorted_objects(object.resource_pools, "name")
      objects += rbac_filtered_sorted_objects(object.vms, "name")
    end
    count_only_or_objects(options[:count_only], objects, nil)
  end
end
