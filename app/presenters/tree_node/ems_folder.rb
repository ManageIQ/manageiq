module TreeNode
  class EmsFolder < Node
    set_attributes(:image, :tooltip) do
      if @object.kind_of?(Datacenter)
        icon = '100/datacenter.png'
        tooltip = _("Datacenter: %{datacenter_name}") % {:datacenter_name => @object.name}
      else
        icon = %i(vandt vat).include?(@options[:type]) ? '100/blue_folder.png' : '100/folder.png'
        tooltip = _("Folder: %{folder_name}") % {:folder_name => @object.name}
      end
      [icon, tooltip]
    end
  end
end
