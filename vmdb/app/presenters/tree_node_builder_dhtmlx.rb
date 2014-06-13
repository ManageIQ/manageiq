class TreeNodeBuilderDHTMLX < TreeNodeBuilder
  def tooltip_key
    'tooltip'
  end

  def open_node
    @node['open'] = '1'
  end

  def generic_node(text, image, tip = nil)
    text = ERB::Util.html_escape(text) unless text.html_safe?
    @node = {
      'id'    => build_object_id,
      'style' => "cursor:default",             # No cursor pointer
      'text'  => text,
    }
    @node['im0'] = @node['im1'] = @node['im2'] = image
    @node['open'] = '1' if options[:open_all]  # Start with all nodes open
    tooltip(tip)
  end

  def normal_folder_node
    prefix = options[:type] == :vandt ? 'blue_' : ''
    @node = {
      'text' => object.name,
      'im0'  => "#{prefix}folder.png",
      'im1'  => "#{prefix}folder_open.png",
      'im2'  => "#{prefix}folder_closed.png",
    }
    tooltip("Folder: #{object.name}")
  end

  def hash_node
    @node = {
      'id'    => build_hash_id,
      'style' => "cursor:default",             # No cursor pointer
      'text'  => object[:text],
    }
    @node['im0'] = @node['im1'] = @node['im2'] = "#{object[:image] || object[:text]}.png"
    @node['open'] = '1' if options[:open_all]  # Start with all nodes open
    tooltip(object[:tip])
  end
end
