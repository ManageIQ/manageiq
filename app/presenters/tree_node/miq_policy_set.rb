module TreeNode
  class MiqPolicySet < Node
    set_attribute(:title, &:description)
    set_attribute(:image) { "100/policy_profile#{@object.active? ? "" : "_inactive"}.png" }
  end
end
