class TreeBuilderIsoDatastores < TreeBuilder

  private

  def tree_init_options(tree_name)
    {:leaf => "IsoDatastore"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "iso_",
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    count_only_or_objects(options[:count_only], IsoDatastore.all, "name")
  end

  def x_get_tree_iso_datastore_kids(object,options)
    iso_images = object.iso_images
    if options[:count_only]
      x_tree[:open_nodes].push("xx-isd_xx-#{to_cid(object.id)}")
      iso_images.size
    else
      objects = []
      if iso_images.size > 0
        x_tree(options[:tree])[:open_nodes].push("isd_xx-#{to_cid(object.id)}")
        objects.push(
          :id    => "isd_xx-#{to_cid(object.id)}",
          :text  => "ISO Images",
          :image => "folder",
          :tip   => "ISO Images"
        )
      end
      objects
    end
  end

  def x_get_tree_custom_kids(object, options)
    nodes = (object[:full_id] || object[:id]).split('_')
    isd = IsoDatastore.find_by_id(from_cid(nodes.last.split('-').last))
    # Iso Datastore node was clicked OR folder nodes was clicked
    objects = isd.iso_images if nodes[0].end_with?("isd")
    count_only_or_objects(options[:count_only], objects, "name")
  end
end
