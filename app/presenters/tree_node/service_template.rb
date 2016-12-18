module TreeNode
  class ServiceTemplate < Node
    set_attribute(:image) { @object.picture ? "/pictures/#{@object.picture.basename}" : '100/service_template.png' }
    set_attribute(:title) do
      if @object.tenant.ancestors.empty?
        @object.name
      else
        "#{@object.name} (#{@object.tenant.name})"
      end
    end
  end
end
