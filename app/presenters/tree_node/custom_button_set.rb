module TreeNode
  class CustomButtonSet < Node
    set_attribute(:title) do
      if @options[:type] == :sandt
        _("%{button_group_name} (Group)") % {:button_group_name => @object.name.split("|").first}
      else
        @object.name.split("|").first
      end
    end

    set_attribute(:image) do
      @object.set_data && @object.set_data[:button_image] ? "100/custom-#{@object.set_data[:button_image]}.png" : '100/folder.png'
    end

    set_attribute(:tooltip) do
      if @object.description
        _("Button Group: %{button_group_description}") % {:button_group_description => @object.description}
      else
        @object.name.split("|").first
      end
    end
  end
end
