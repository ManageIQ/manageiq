class ApplicationHelper::Button::WidgetNew < ApplicationHelper::Button::ButtonNewDiscover
  def visible?
    super && @view_context.x_node != 'root'
  end
end
