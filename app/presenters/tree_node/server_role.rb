module TreeNode
  class ServerRole < Node
    set_attribute(:image) { "100/role.png" }
    set_attribute(:expand, true)

    set_attributes(:title, :tooltip) do
      status = "stopped"
      @object.assigned_server_roles.where(:active => true).each do |asr| # Go thru all active assigned server roles
        next unless asr.miq_server.started? # Find a started server
        if @options[:parent_kls] == "MiqRegion" || # it's in the region
           (@options[:parent_kls] == "Zone" && asr.miq_server.my_zone == @options[:parent_name]) # it's in the zone
          status = "active"
          break
        end
      end
      text = _("Role: %{description} (%{status})") % {:description => @object.description, :status => status}
      [text, text]
    end
  end
end
