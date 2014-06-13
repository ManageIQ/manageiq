class TreeNodeBuilderDynatree < TreeNodeBuilder
  def tooltip_key
    :tooltip
  end

  def open_node
    @node[:expand] = true
  end

  def generic_node(text, image, tip = nil)
    text = ERB::Util.html_escape(text) unless text.html_safe?
    @node = {
      :key   => build_object_id,
      :title => text,
      :icon  => image,
    }
    @node[:expand] = true if options[:open_all]  # Start with all nodes open
    tooltip(tip)
  end

  def normal_folder_node
    icon = options[:type] == :vandt ? "blue_folder.png" : "folder.png"
    generic_node(object.name, icon, "Folder: #{object.name}")
    @node
  end

  def hash_node
    # FIXME: expansion
    @node = {
      :key   => build_hash_id,
      :icon  => "#{object[:image] || object[:text]}.png",
      :title => ERB::Util.html_escape(object[:text]),
    }
    @node[:expand] = true if options[:open_all] # Start with all nodes open
    @node[:cfmeNoClick] = object[:cfmeNoClick] if object.key?(:cfmeNoClick)

    # FIXME: check the following
    # TODO: With dynatree, unless folders are open, we can't jump to a child node until it has been visible once
    # node[:expand] = false

    tooltip(object[:tip])
  end
end
