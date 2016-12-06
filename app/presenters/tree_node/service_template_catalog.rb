module TreeNode
  class ServiceTemplateCatalog < Node
    set_attribute(:image, '100/service_template_catalog.png')
    set_attribute(:title) do
      if @object.tenant.present? && @object.tenant.ancestors.present?
        "#{@object.name} (#{@object.tenant.name})"
      else
        @object.name
      end
    end
  end
end
