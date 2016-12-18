module TreeNode
  class CustomButton < Node
    set_attribute(:image) do
      @object.options && @object.options[:button_image] ? "100/custom-#{@object.options[:button_image]}.png" : '100/leaf.gif'
    end

    set_attribute(:tooltip) { _("Button: %{button_description}") % {:button_description => @object.description} }
  end
end
