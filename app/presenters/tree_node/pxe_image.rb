module TreeNode
  class PxeImage < Node
    set_attribute(:image) { "100/#{@object.default_for_windows ? 'win32service' : 'pxeimage'}.png" }
  end
end
