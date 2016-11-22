class ApplicationHelper::Button::DialogResourceRemove < ApplicationHelper::Button::Dialog
  def visible?
    super && @view_context.edit_typ != 'add' && @view_context.x_node != 'root'
  end
end
