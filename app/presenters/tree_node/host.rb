module TreeNode
  class Host < Node
    set_attribute(:image, '100/host.png')
    set_attribute(:tooltip) { "#{ui_lookup(:table => "host")}: #{@object.name}" }
  end
end
