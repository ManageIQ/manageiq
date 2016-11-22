class ApplicationHelper::Button::DialogAction < ApplicationHelper::Button::Basic
  def visible?
    !@edit || !@edit[:current]
  end
end
