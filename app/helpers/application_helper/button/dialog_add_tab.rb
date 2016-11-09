class ApplicationHelper::Button::DialogAddTab < ApplicationHelper::Button::Dialog
  def visible?
    super && nodes.length <= 2
  end
end
