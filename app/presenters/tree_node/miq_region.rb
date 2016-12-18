module TreeNode
  class MiqRegion < Node
    set_attribute(:image, '100/miq_region.png')
    set_attribute(:tooltip) { @object[0] }
    set_attribute(:expand, true)
  end
end
