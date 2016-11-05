module TreeNode
  class Condition < Node
    set_attribute(:title, &:description)
    set_attribute(:image, '100/miq_condition.png')
  end
end
