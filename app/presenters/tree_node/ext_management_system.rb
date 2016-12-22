module TreeNode
  class ExtManagementSystem < Node
    set_attribute(:image) { "svg/vendor-#{@object.image_name}.svg" }

    set_attribute(:tooltip) do
      # # TODO: This should really leverage .base_model on an EMS
      prefix_model = case @object
                     when EmsCloud then "EmsCloud"
                     when EmsInfra then "EmsInfra"
                     else               "ExtManagementSystem"
                     end
      "#{ui_lookup(:model => prefix_model)}: #{@object.name}"
    end
  end
end
