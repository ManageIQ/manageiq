class ApplicationHelper::Button::RoleStart < ApplicationHelper::Button::RolePowerOptions
  needs :@record

  def calculate_properties
    super
    self[:title] = @error_message if disabled?
  end

  def disabled?
    @error_message = if @record.class == AssignedServerRole
                       if @record.active
                         N_("This Role is already active on this Server")
                       elsif !@record.miq_server.started?
                         N_("Only available Roles on active Servers can be started")
                       elsif x_node != "root" && @record.server_role.regional_role?
                         N_("This role can only be managed at the Region level")
                       end
                     end
    @error_message.present?
  end
end
