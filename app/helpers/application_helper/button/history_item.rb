class ApplicationHelper::Button::HistoryItem < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @view_context.x_tree_history.length > 1
      self["text"] = @view_context.x_tree_history[self['id'].split("_").last.to_i][:text]
    end
  end
end
