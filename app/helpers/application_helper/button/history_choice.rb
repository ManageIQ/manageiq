class ApplicationHelper::Button::HistoryChoice < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    # Show disabled history button if no history
    if @view_context.x_tree_history.length < 2
      self[:enabled] = false
    end
  end
end
