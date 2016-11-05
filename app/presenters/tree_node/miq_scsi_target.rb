module TreeNode
  class MiqScsiTarget < Node
    set_attribute(:image, '100/target_scsi.png')

    set_attributes(:title, :tooltip) do
      title = if @object.iscsi_name.blank?
                _("SCSI Target %{target}") % {:target => @object.target}
              else
                _("SCSI Target %{target} (%{name})") % {:target => @object.target, :name => @object.iscsi_name}
              end
      [title, _("Target: %{text}") % {:text => title}]
    end
  end
end
