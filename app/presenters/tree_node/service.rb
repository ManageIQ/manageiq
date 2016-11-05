module TreeNode
  class Service < Node
    set_attribute(:image) { @object.picture ? "/pictures/#{@object.picture.basename}" : "/service.png" }
  end
end
