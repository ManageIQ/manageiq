class TreeNodeDefaultFiltersBuilder < TreeNodeBuilder
  def build
    case object
      when Hash                      then hash_node
      when MiqSearch                 then generic_node(object)
    end
  end

  def generic_node(object)
    TreeNodeBuilder.generic_tree_node(
        object[:id].to_s,
        object[:description],
        "filter.png",
        object[:description],
        :style_class => "cfme-no-cursor-node",
        :select      => object[:search_key] != "_hidden_"
    )
  end
end