class ApplicationHelper::Button::OldDialogsEditDelete < ApplicationHelper::Button::Basic
  def disabled?
    if @view_context.x_active_tree == :old_dialogs_tree && @record && @record[:default]
      @error_message = if self[:id] =~ /_edit/
                         _('Default dialogs cannot be edited')
                       else
                         _('Default dialogs cannot be removed from the VMDB')
                       end
    end
    @error_message.present?
  end
end
