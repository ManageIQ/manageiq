class TreeNodeBuilderMiqActionCat  < TreeNodeBuilder

  def classification_node
    img = "blank.gif"
    leaf = !object.entries.any?

    if !leaf
      img = "tag.png"
    end

    generic_node(object.description, img, _("Category: %{description}") % {:description => object.description})

    if !leaf
      @node[:cfmeNoClick] = true
    end
    @node[:hideCheckbox] = true
    @node
  end
end
