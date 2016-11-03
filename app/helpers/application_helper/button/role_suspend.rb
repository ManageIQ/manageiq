class ApplicationHelper::Button::RoleSuspend < ApplicationHelper::Button::RolePowerOptions
  needs :@record, :@sb

  def calculate_properties
    super
    self[:title] = @error_message if disabled?
  end

  def disabled?
    @error_message = if @view_context.x_node != "root" && @record.server_role.regional_role?
                       _("This role can only be managed at the Region level")
                     else
                       if @record.active
                         unless @record.server_role.max_concurrent != 1
                           _("Activate the %{server_role_description} Role on another Server to suspend it on %{server_name} [%{server_id}]") %
                             {:server_role_description => @record.server_role.description,
                              :server_name             => @record.miq_server.name,
                              :server_id               => @record.miq_server.id}
                         end
                       else
                         _("Only active Roles on active Servers can be suspended")
                       end
                     end
    @error_message.present?
  end
end
