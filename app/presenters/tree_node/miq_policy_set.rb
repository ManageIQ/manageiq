module TreeNode
  class MiqPolicySet < Node
    set_attribute(:title, &:description)
    set_attribute(:image) { "policy_profile#{@object.active? ? "" : "_inactive"}.png" }
  end
end
