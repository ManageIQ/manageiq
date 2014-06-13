class TreeBuilderRegion  < TreeBuilder
  private

  def tree_init_options(tree_name)
    ent = MiqEnterprise.my_enterprise
    {:leaf => ent.is_enterprise? ? "MiqEnterprise" : "MiqRegion", :add_root => ent.is_enterprise?}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    ent = MiqEnterprise.my_enterprise
    objects = ent.miq_regions.sort_by { |a| a.description.downcase }
    count_only_or_objects(options[:count_only], objects, nil)
  end

  def x_get_tree_region_kids(object, options)
    emstype = if [:bottlenecks, :utilization].include?(options[:type])
                object.ems_infras
              else
                object.ext_management_systems
              end
    emses = rbac_filtered_objects(emstype)
    storages  = rbac_filtered_objects(object.storages)
    if options[:count_only]
      emses.count + storages.count
    else
      objects = []
      if emses.count > 0
        objects.push(:id => "folder_e_xx-#{to_cid(object.id)}", :text => ui_lookup(:tables => "ext_management_systems"),
                     :image => "folder", :tip => "#{ui_lookup(:tables => "ext_management_systems")} (Click to open)")
      end
      if storages.count > 0
        objects.push(:id => "folder_ds_xx-#{to_cid(object.id)}", :text => ui_lookup(:tables => "storages"),
                     :image => "folder", :tip => "#{ui_lookup(:tables => "storages")} (Click to open)")
      end
      objects
    end
  end

  def x_get_tree_custom_kids(object, options)
    nodes = object[:id].split('_')
    id = from_cid(nodes.last.split('-').last)
    if object_ems?(nodes, object)
      rec = MiqRegion.find_by_id(id)
      objects = rbac_filtered_sorted_objects(rec.ems_infras, "name")
      count_only_or_objects(options[:count_only], objects, nil)
    elsif object_ds?(nodes, object)
      rec = MiqRegion.find_by_id(id)
      objects = rbac_filtered_sorted_objects(rec.storages, "name")
      count_only_or_objects(options[:count_only], objects, nil)
    elsif object_cluster?(nodes, object)
      rec = ExtManagementSystem.find_by_id(id)
      objects = rbac_filtered_sorted_objects(rec.ems_clusters, "name") +
                rbac_filtered_sorted_objects(rec.non_clustered_hosts, "name")
      count_only_or_objects(options[:count_only], objects, nil)
    end
  end

  def object_ems?(nodes, object)
    (nodes.length > 1 && nodes[1] == "e") ||
      (object[:full_id] && object[:full_id].split('_')[1] == "e")
  end

  def object_ds?(nodes, object)
    (nodes.length > 1 && nodes[1] == "ds") ||
      (object[:full_id] && object[:full_id].split('_')[1] == "ds")
  end

  def object_cluster?(nodes, object)
    (nodes.length > 1 && nodes[1] == "c") ||
      (object[:full_id] && object[:full_id].split('_')[1] == "c")
  end

  def rbac_filtered_sorted_objects(records, sort_by, options = {})
    rbac_filtered_objects(records, options).sort_by { |o| o.deep_send(sort_by).to_s.downcase }
  end
end
