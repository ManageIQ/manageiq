module TreeBuilderCommon
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
        :tip   => "#{ui_lookup(:tables => "ems_clusters")} (#{click_to_open})"
      }
    ]
  end
end
