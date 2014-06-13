class TreeBuilderPxeServers < TreeBuilder

  private

  def tree_init_options(tree_name)
    {:leaf => "PxeServer"}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(
      :id_prefix => "ps_",
      :autoload  => true
    )
  end

  # Get root nodes count/array for explorer tree
  def x_get_tree_roots(options)
    count_only_or_objects(options[:count_only], PxeServer.all, "name")
  end

  def x_get_tree_pxe_server_kids(object,options)
    pxe_images = object.pxe_images
    win_images = object.windows_images
    if options[:count_only]
      x_tree[:open_nodes].push("xx-pxe_xx-#{to_cid(object.id)}") unless x_tree[:open_nodes].include?("xx-pxe_xx-#{to_cid(object.id)}")
      x_tree[:open_nodes].push("xx-win_xx-#{to_cid(object.id)}") unless x_tree[:open_nodes].include?("xx-win_xx-#{to_cid(object.id)}")
      pxe_images.size + win_images.size
    else
      objects = []
      if pxe_images.size > 0
        x_tree[:open_nodes].push("pxe_xx-#{to_cid(object.id)}") unless x_tree[:open_nodes].include?("pxe_xx-#{to_cid(object.id)}")
        objects.push(:id => "pxe_xx-#{to_cid(object.id)}", :text => "PXE Images", :image => "folder", :tip => "PXE Images")
      end
      if win_images.size > 0
        x_tree[:open_nodes].push("win_xx-#{to_cid(object.id)}") unless x_tree[:open_nodes].include?("win_xx-#{to_cid(object.id)}")
        objects.push(:id => "win_xx-#{to_cid(object.id)}", :text => "Windows Images", :image => "folder", :tip => "Windows Images")
      end
      objects
    end
  end

  def x_get_tree_custom_kids(object, options)
    nodes = (object[:full_id] || object[:id]).split('_')
    ps = PxeServer.find_by_id(from_cid(nodes.last.split('-').last))
    objects = if nodes[0].end_with?("pxe")
                ps.pxe_images
              elsif nodes[0].end_with?("win")
                ps.windows_images
              end
    count_only_or_objects(options[:count_only], objects, "name")
  end
end
