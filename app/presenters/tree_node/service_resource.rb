module TreeNode
  class ServiceResource < Node
    set_attribute(:image) { "100/#{@object.resource_type == 'VmOrTemplate' ? 'vm' : 'service_template'}.png" }
  end
end
