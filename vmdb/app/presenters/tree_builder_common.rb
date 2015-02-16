module TreeBuilderCommon
  def x_get_tree_ems_kids(object, options)
    ems_clusters = rbac_filtered_objects(object.ems_clusters)
    non_clustered_hosts = rbac_filtered_objects(object.non_clustered_hosts)
    ems_clusters_count = ems_clusters.count
    non_clustered_hosts_count = non_clustered_hosts.count
    if options[:count_only]
      ems_clusters_count + non_clustered_hosts_count
    else
      objects = []
      if ems_clusters_count > 0 || non_clustered_hosts_count > 0
        objects.push(:id    => "folder_c_xx-#{to_cid(object.id)}",
                     :text  => ui_lookup(:ems_cluster_types => "cluster"),
                     :image => "folder",
                     :tip   => "#{ui_lookup(:tables => "ems_clusters")} (Click to open)")
      end
      objects
    end
  end
end
