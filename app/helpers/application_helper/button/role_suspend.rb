class ApplicationHelper::Button::RoleSuspend < ApplicationHelper::Button::RolePowerOptions
  needs :@record, :@sb

  def disabled?
    @error_message = if @view_context.x_node != 'root' && @record.server_role.regional_role?
                       _('This role can only be managed at the Region level')
                     elsif @record.active && @record.server_role.max_concurrent == 1
                       _("Activate the %{server_role_description} Role on another Server to \
suspend it on %{server_name} [%{server_id}]") %
                         {:server_role_description => @record.server_role.description,
                          :server_name             => @record.miq_server.name,
                          :server_id               => @record.miq_server.id}
                     else
                       _('Only active Roles on active Servers can be suspended')
                     end
    @error_message.present?
  end
end
