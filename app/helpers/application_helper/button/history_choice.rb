class ApplicationHelper::Button::HistoryChoice < ApplicationHelper::Button::ButtonWithoutRbacCheck
  def disabled?
    @view_context.x_tree_history.length < 2
  end
end
