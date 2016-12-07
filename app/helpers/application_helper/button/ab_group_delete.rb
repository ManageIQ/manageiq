class ApplicationHelper::Button::AbGroupDelete < ApplicationHelper::Button::AbGroupEdit
  def disabled?
    @error_message = _('Selected Custom Button Group cannot be deleted') if unassigned_button_group?
    @error_message.present?
  end
end
