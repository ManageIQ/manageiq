module TreeNode
  class OrchestrationTemplate < Node
    set_attribute(:image) do
      suffix = @object.class.name.underscore.split("_").last.downcase
      suffix = 'vapp' if suffix == 'template'
      "100/orchestration_template_#{suffix}.png"
    end
  end
end
