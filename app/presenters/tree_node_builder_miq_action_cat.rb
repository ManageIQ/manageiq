class TreeNodeBuilderMiqActionCat < TreeNodeBuilder
  def classification_node
    img = "blank.gif"
    leaf = !object.entries.any?
    img = "tag.png" unless leaf
    generic_node(object.description, img, _("Category: %{description}") % {:description => object.description})
    @node[:cfmeNoClick] = true unless leaf
    @node[:hideCheckbox] = true
    @node
  end
end
