class TreeNodeBuilderSmartproxyAffinity < TreeNodeBuilder
  def generic_node(node)
    ret = super(node)
    @node[:cfmeNoClick] = true
    ret
  end
end
