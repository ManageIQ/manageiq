class TreeNodeBuilderSmartproxyAffinity < TreeNodeBuilder
  def miq_server_node
    ret = super
    @node[:cfmeNoClick] = true
    ret
  end
end
