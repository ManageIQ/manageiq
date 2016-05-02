class TreeBuilderOps < TreeBuilder
  # common methods for OPS subclasses
  has_kids_for LdapRegion, [:x_get_tree_lr_kids]
  has_kids_for Zone, [:x_get_tree_zone_kids]

  private

  def active_node_set(_tree_nodes)
    # FIXME: check all below
    case @name
    when :vmdb_tree
      @tree_state.x_node_set("root", @name)
    else
      @tree_state.x_node_set("svr-#{to_cid(MiqServer.my_server(true).id)}", @name) unless @tree_state.x_node(@name)
    end
  end

  def x_get_tree_zone_kids(object, count_only)
    count_only_or_objects(count_only, object.miq_servers, "name")
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    region = MiqRegion.my_region
    objects = region.zones.sort_by { |z| z.name.downcase }
    count_only_or_objects(count_only, objects, nil)
  end

  def x_get_tree_lr_kids(object, count_only)
    if count_only
      return (object.ldap_domains.count)
    else
      return (object.ldap_domains.sort_by { |a| a.name.to_s })
    end
  end
end
