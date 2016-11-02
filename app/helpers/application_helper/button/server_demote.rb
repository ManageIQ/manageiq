class ApplicationHelper::Button::ServerDemote < ApplicationHelper::Button::ServerLevelOptions
  needs :@record, :@sb

  def calculate_properties
    super
    self[:title] = @error_message if disabled?
  end

  def disabled?
    @error_message = if @record.master_supported?
                       if @record.priority == 1 || @record.priority == 2
                         if @view_context.x_node != "root" && @record.server_role.regional_role?
                           N_("This role can only be managed at the Region level")
                         end
                       end
                     end
    @error_message.present?
  end
end
