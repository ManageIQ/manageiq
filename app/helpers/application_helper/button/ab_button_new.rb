class ApplicationHelper::Button::AbButtonNew < ApplicationHelper::Button::Basic
  def visible?
    !(@view_context.x_active_tree == :ab_tree &&
      @view_context.x_node.split('_').length == 2 &&
      @view_context.x_node.split('_')[0] == "xx-ab")
  end
end
