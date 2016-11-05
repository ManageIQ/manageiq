module TreeNode
  class DialogField < Node
    set_attribute(:title, &:label)
    set_attribute(:image, '100/dialog_field.png')
  end
end
