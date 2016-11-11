class ApplicationHelper::Button::AbGroupEdit < ApplicationHelper::Button::Basic
  def initialize(view_context, view_binding, instance_data, props)
    super
    @action = props[:options][:action]
  end

  def calculate_properties
    super
    self[:title] = @error_message if @error_message.present?
  end

  def disabled?
    @error_message = _('Selected Custom Button Group cannot be %{action}') %
                     {:action => @action} if unassigned_button_group?
    @error_message.present?
  end

  private

  def unassigned_button_group?
    @view_context.x_node.split('-')[1] == 'ub'
  end
end
