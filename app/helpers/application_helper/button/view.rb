class ApplicationHelper::Button::View < ApplicationHelper::Button::Basic
  def skip?
    # only hide gtl button if they are not in @gtl_buttons
    @gtl_buttons && !@gtl_buttons.include?(self[:id].to_s)
  end
end
