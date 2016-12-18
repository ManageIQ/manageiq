module TreeNode
  class GuestDevice < Node
    set_attribute(:title, &:device_name)

    set_attributes(:image, :tooltip) do
      if @object.device_type == "ethernet"
        image = '100/pnic.png'
        tooltip = _("Physical NIC: %{name}") % {:name => @object.device_name}
      else
        image = "100/sa_#{@object.controller_type.downcase}.png"
        tooltip = _("%{type} Storage Adapter: %{name}") % {:type => @object.controller_type, :name => @object.device_name}
      end

      [image, tooltip]
    end
  end
end
