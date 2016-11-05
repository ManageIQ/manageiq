module TreeNode
  class MiqWidget < Node
    set_attribute(:title, &:title)
    set_attribute(:tooltip, &:title)
    set_attribute(:image) { "100/#{@object.content_type}_widget.png" }
  end
end
