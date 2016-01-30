class ApplicationHelper::Button::HistoryItem < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @view_context.x_tree_history.length > history_item_id
      self["text"] = @view_context.x_tree_history[history_item_id][:text]
    end
  end

  # History toolbar is a strange beast. The yaml definition contains bunch of pre-defined
  # buttons and these are then hidden one by one by the following code.
  # TODO: Generate the buttons from the history instead.
  def history_item_id
    @history_item_id ||= self['id'].split("_").last.to_i
    @history_item_id
  end

  def skip?
    !@view_context.x_tree_history[history_item_id] && history_item_id != 1
  end
end
