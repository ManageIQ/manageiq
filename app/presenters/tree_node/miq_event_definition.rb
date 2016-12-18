module TreeNode
  class MiqEventDefinition < Node
    set_attribute(:title, &:description)
    set_attribute(:image) { "100/event-#{@object.name}.png" }
  end
end
