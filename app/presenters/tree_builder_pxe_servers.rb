class TreeBuilderPxeServers < TreeBuilder
  has_kids_for PxeServer, [:x_get_tree_pxe_server_kids]

  private

  def tree_init_options(_tree_name)
    {:leaf => "PxeServer"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true)
  end

  def root_options
    [t = _("All PXE Servers"), t]
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, PxeServer.all, "name")
  end

  def x_get_tree_pxe_server_kids(object, count_only)
    pxe_images = object.pxe_images
    win_images = object.windows_images
    open_nodes = @tree_state.x_tree(@name)[:open_nodes]
    if count_only
      open_nodes.push("xx-pxe_xx-#{to_cid(object.id)}") unless open_nodes.include?("xx-pxe_xx-#{to_cid(object.id)}")
      open_nodes.push("xx-win_xx-#{to_cid(object.id)}") unless open_nodes.include?("xx-win_xx-#{to_cid(object.id)}")
      pxe_images.size + win_images.size
    else
      objects = []
      if pxe_images.size > 0
        open_nodes.push("pxe_xx-#{to_cid(object.id)}") unless open_nodes.include?("pxe_xx-#{to_cid(object.id)}")
        objects.push(:id    => "pxe_xx-#{to_cid(object.id)}",
                     :text  => _("PXE Images"),
                     :image => "100/folder.png",
                     :tip   => _("PXE Images"))
      end
      if win_images.size > 0
        open_nodes.push("win_xx-#{to_cid(object.id)}") unless open_nodes.include?("win_xx-#{to_cid(object.id)}")
        objects.push(:id    => "win_xx-#{to_cid(object.id)}",
                     :text  => _("Windows Images"),
                     :image => "100/folder.png",
                     :tip   => _("Windows Images"))
      end
      objects
    end
  end

  def x_get_tree_custom_kids(object, count_only, _options)
    nodes = (object[:full_id] || object[:id]).split('_')
    ps = PxeServer.find_by_id(from_cid(nodes.last.split('-').last))
    objects = if nodes[0].end_with?("pxe")
                ps.pxe_images
              elsif nodes[0].end_with?("win")
                ps.windows_images
              end
    count_only_or_objects(count_only, objects, "name")
  end
end
