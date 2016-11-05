module TreeNode
  class DialogGroup < Node
    set_attribute(:title, &:label)
    set_attribute(:image, '100/dialog_group.png')
  end
end
