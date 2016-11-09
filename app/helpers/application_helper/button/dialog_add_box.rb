class ApplicationHelper::Button::DialogAddBox < ApplicationHelper::Button::Dialog
  def visible?
    super && (nodes.length == 2 || nodes.length == 3)
  end
end
