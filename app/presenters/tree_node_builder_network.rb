class TreeNodeBuilderNetwork < TreeNodeBuilder
  def generic_node(text, image, tip = nil)
    ret = super(text, image, tip)
    @node[:cfmeNoClick] = true unless image.start_with?('currentstate')
    ret
  end
end
