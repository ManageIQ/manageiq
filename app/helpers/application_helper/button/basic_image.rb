class ApplicationHelper::Button::BasicImage < ApplicationHelper::Button::Basic
  def visible?
    active_node = @view_context.x_node
    active_node.blank? || (active_node != "xx-arch" && active_node != "xx-orph")
  end
end
