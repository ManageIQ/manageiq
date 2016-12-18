module TreeNode
  class EmsCluster < Node
    set_attribute(:image, '100/cluster.png')
    set_attribute(:tooltip) { "#{ui_lookup(:table => "ems_cluster")}: #{@object.name}" }
  end
end
