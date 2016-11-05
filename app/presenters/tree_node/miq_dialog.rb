module TreeNode
  class MiqDialog < Node
    set_attribute(:title, &:description)
    set_attribute(:image, '100/miqdialog.png')
    set_attribute(:tooltip) { @object[0] }
  end
end
