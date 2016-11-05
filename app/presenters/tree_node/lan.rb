module TreeNode
  class Lan < Node
    set_attribute(:image, '100/lan.png')
    set_attribute(:tooltip) { _("Port Group: %{name}") % {:name => @object.name} }
  end
end
