class TreeBuilderOps < TreeBuilder
  #common methods for OPS subclasses
  private

  def active_node_set(tree_nodes)
    case @name
    when :vmdb_tree
      x_node_set("root", @name)
    else
      x_node_set("svr-#{to_cid(MiqServer.my_server(true).id)}", @name) unless x_node(@name)
    end

  end

  def x_get_tree_zone_kids(object, options)
    count_only_or_objects(options[:count_only], object.miq_servers, "name")
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    region = MiqRegion.my_region
    objects = region.zones.sort_by{|z| z.name.downcase}
    count_only_or_objects(options[:count_only], objects, nil)
  end
end
