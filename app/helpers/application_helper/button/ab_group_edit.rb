# This class describes the behavior of both ab_group_edit and ab_group_delete
# buttons, hence they differ only in the disable message.
class ApplicationHelper::Button::AbGroupEdit < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @error_message if @error_message.present?
  end

  def disabled?
    @error_message = ERROR_MSG[self[:child_id].to_sym] if unassigned_button_group?
    @error_message.present?
  end

  private

  ERROR_MSG = {
    :ab_group_edit   => N_('Selected Custom Button Group cannot be edited'),
    :ab_group_delete => N_('Selected Custom Button Group cannot be deleted')
  }.freeze

  # Checks, whether it's an Unassigned Button group
  def unassigned_button_group?
    @view_context.x_node.split('-')[1] == 'ub'
  end
end
