class TreeNodeBuilderComplianceHistory < TreeNodeBuilder
  def hash_node
    text = object[:text].html_safe
    @node = {:key   => build_hash_id,
             :icon  => node_icon("#{object[:image]}.png"),
             :title => text}
    # Start with all nodes open unless expand is explicitly set to false
    @node[:expand] = true if options[:open_all] && options[:expand] != false
    @node[:cfmeNoClick] = object[:cfmeNoClick]
    tooltip(object[:tip])
  end
end
