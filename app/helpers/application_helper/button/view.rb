class ApplicationHelper::Button::View < ApplicationHelper::Button::ButtonWithoutRbacCheck
  def visible?
    # only hide gtl button if they are not in @gtl_buttons
    !@gtl_buttons || @gtl_buttons.include?(self[:id].to_s)
  end
end
