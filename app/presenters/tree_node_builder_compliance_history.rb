class TreeNodeBuilderComplianceHistory < TreeNodeBuilder
  def expand_node?
    options[:open_all] && options[:expand] != false
  end

  def hash_node
    text = object[:text].html_safe
    @node = {:key         => build_hash_id,
             :icon        => node_icon("#{object[:image]}.png"),
             :cfmeNoClick => true,
             :title       => text}
    # Start with all nodes open unless expand is explicitly set to false
    @node[:expand] = true if expand_node?
    @node[:cfmeNoClick] = object[:cfmeNoClick]
    tooltip(object[:tip])
  end

  def generic_node(node)
    ret = super(node)
    @node[:cfmeNoClick] = true
    ret
  end
end
