class ApplicationHelper::Button::ShowSummary < ApplicationHelper::Button::ButtonWithoutRbacCheck
  def visible?
    !@explorer
  end
end
