class TreeNodeBuilderNetwork < TreeNodeBuilder
  def generic_node(node)
    ret = super(node)
    @node[:cfmeNoClick] = true unless node.image.start_with?('100/currentstate-')
    ret
  end
end
