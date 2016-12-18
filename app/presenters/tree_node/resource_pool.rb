module TreeNode
  class ResourcePool < Node
    set_attribute(:image) { "100/#{@object.vapp ? 'vapp' : 'resource_pool'}.png" }
  end
end
