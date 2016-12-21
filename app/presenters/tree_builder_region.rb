class TreeBuilderRegion < TreeBuilder
  has_kids_for MiqRegion, [:x_get_tree_region_kids]

  private

  def tree_init_options(_tree_name)
    ent = MiqEnterprise.my_enterprise
    {:leaf => ent.is_enterprise? ? "MiqEnterprise" : "MiqRegion", :add_root => ent.is_enterprise?}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    ent = MiqEnterprise.my_enterprise
    objects = ent.miq_regions.sort_by { |a| a.description.downcase }
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_region_kids(object, count_only)
    emstype = if [:bottlenecks, :utilization].include?(@type)
                object.ems_infras
              else
                object.ext_management_systems
              end
    emses = Rbac.filtered(emstype)
    storages = Rbac.filtered(object.storages)
    if count_only
      emses.count + storages.count
    else
      objects = []
      if emses.count > 0
        objects.push(:id => "folder_e_xx-#{to_cid(object.id)}", :text => ui_lookup(:tables => "ext_management_systems"),
                     :image => "100/folder.png", :tip => _("%{tables} (Click to open)") %
                                                 {:tables => ui_lookup(:tables => "ext_management_systems")})
      end
      if storages.count > 0
        objects.push(:id => "folder_ds_xx-#{to_cid(object.id)}", :text => ui_lookup(:tables => "storages"),
                     :image => "100/folder.png", :tip => _("%{tables} (Click to open)") %
                                                 {:tables => ui_lookup(:tables => "storages")})
      end
      objects
    end
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    nodes = object[:id].split('_')
    id = from_cid(nodes.last.split('-').last)
    if object_ems?(nodes, object)
      rec = MiqRegion.find_by_id(id)
      objects = rbac_filtered_sorted_objects(rec.ems_infras, "name")
      count_only_or_objects(count_only, objects)
    elsif object_ds?(nodes, object)
      rec = MiqRegion.find_by_id(id)
      objects = rbac_filtered_sorted_objects(rec.storages, "name")
      count_only_or_objects(count_only, objects)
    elsif object_cluster?(nodes, object)
      rec = ExtManagementSystem.find_by_id(id)
      objects = rbac_filtered_sorted_objects(rec.ems_clusters, "name") +
                rbac_filtered_sorted_objects(rec.non_clustered_hosts, "name")
      count_only_or_objects(count_only, objects)
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
    Rbac.filtered(records, options).sort_by { |o| o.deep_send(sort_by).to_s.downcase }
  end
end
