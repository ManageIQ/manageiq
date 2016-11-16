class ApplicationHelper::Button::OldDialogsEditDelete < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @view_context.x_active_tree == :old_dialogs_tree && @record && @record[:default]
      self[:enabled] = false
      self[:title] = if self[:id] =~ /_edit/
                       _('Default dialogs cannot be edited')
                     else
                       _('Default dialogs cannot be removed from the VMDB')
                     end
    end
  end
end
