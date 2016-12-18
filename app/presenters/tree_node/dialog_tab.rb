module TreeNode
  class DialogTab < Node
    set_attribute(:title, &:label)
    set_attribute(:image, '100/dialog_tab.png')
  end
end
