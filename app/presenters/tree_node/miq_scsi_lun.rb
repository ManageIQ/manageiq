module TreeNode
  class MiqScsiLun < Node
    set_attribute(:title, &:canonical_name)
    set_attribute(:image, '100/lun.png')
    set_attribute(:tooltip) { _("LUN: %{name}") % {:name => @object.canonical_name} }
  end
end
