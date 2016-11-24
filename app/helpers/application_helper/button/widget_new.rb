class ApplicationHelper::Button::WidgetNew < ApplicationHelper::Button::Basic
  def visible?
    @view_context.x_node != 'root'
  end
end
