class TreeNodeBuilderSmartproxyAffinity < TreeNodeBuilder
  def generic_node(text, image, tip = nil)
    ret = super(text, image, tip)
    @node[:cfmeNoClick] = true
    ret
  end
end
