module TreeNode
  class Dialog < Node
    set_attribute(:title, &:label)
    set_attribute(:image, '100/dialog.png')
  end
end
