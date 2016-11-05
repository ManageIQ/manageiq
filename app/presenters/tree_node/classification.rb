module TreeNode
  class Classification < Node
    set_attribute(:title, &:description)
    set_attribute(:image, "100/folder.png")
    set_attribute(:click, false)
    set_attribute(:hide_checkbox, true)
    set_attribute(:tooltip) { _("Category: %{description}") % { :description => @object.description } }
  end
end
