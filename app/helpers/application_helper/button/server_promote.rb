class ApplicationHelper::Button::ServerPromote < ApplicationHelper::Button::ServerLevelOptions
  needs :@record, :@sb

  def disabled?
    @error_message = if @record.master_supported?
                       if @record.priority != 1
                         if @view_context.x_node != "root" && @record.server_role.regional_role?
                           _("This role can only be managed at the Region level")
                         end
                       end
                     end
    @error_message.present?
  end
end
