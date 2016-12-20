class TreeBuilderIsoDatastores < TreeBuilder
  has_kids_for IsoDatastore, [:x_get_tree_iso_datastore_kids]

  private

  def tree_init_options(_tree_name)
    {:leaf => "IsoDatastore"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("All ISO Datastores"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, IsoDatastore.all, "name")
  end

  def x_get_tree_iso_datastore_kids(object, count_only)
    iso_images = object.iso_images
    if count_only
      @tree_state.x_tree(@name)[:open_nodes].push("xx-isd_xx-#{to_cid(object.id)}")
      iso_images.size
    else
      objects = []
      if iso_images.size > 0
        @tree_state.x_tree(@name)[:open_nodes].push("isd_xx-#{to_cid(object.id)}")
        objects.push(
          :id    => "isd_xx-#{to_cid(object.id)}",
          :text  => _("ISO Images"),
          :image => "100/folder.png",
          :tip   => _("ISO Images")
        )
      end
      objects
    end
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    nodes = (object[:full_id] || object[:id]).split('_')
    isd = IsoDatastore.find_by_id(from_cid(nodes.last.split('-').last))
    # Iso Datastore node was clicked OR folder nodes was clicked
    objects = isd.iso_images if nodes[0].end_with?("isd")
    count_only_or_objects(count_only, objects, "name")
  end
end
