class ApplicationHelper::Button::DialogAction < ApplicationHelper::Button::ButtonWithoutRbacCheck
  def visible?
    !@edit || !@edit[:current]
  end
end
