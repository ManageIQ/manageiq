module TreeNode
  class Node < NodeBuilder
    set_attribute(:title, &:name)
    set_attribute(:tooltip, nil)
  end
end
