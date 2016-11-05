module TreeNode
  class Switch < Node
    set_attribute(:image, '100/switch.png')
    set_attribute(:tooltip) { _("Switch: %{name}") % {:name => @object.name} }
  end
end
