module TreeNode
  class Tenant < Node
    set_attribute(:image) { "100/#{@object.tenant? ? "tenant" : "project"}.png" }
  end
end
