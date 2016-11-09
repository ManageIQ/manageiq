class ApplicationHelper::Button::DialogResDiscard < ApplicationHelper::Button::Dialog
  def visible?
    super && @view_context.edit_typ == 'add'
  end
end
