module TreeNode
  class Service < Node
    set_attribute(:image) { @object.picture ? "/pictures/#{@object.picture.basename}" : '100/service.png' }
  end
end
