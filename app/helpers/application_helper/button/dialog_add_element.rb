class ApplicationHelper::Button::DialogAddElement < ApplicationHelper::Button::Dialog
  def visible?
    super && (nodes.length == 3 || nodes.length == 4)
  end
end
