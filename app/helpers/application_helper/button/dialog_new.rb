class ApplicationHelper::Button::DialogNew < ApplicationHelper::Button::DialogAction
  include ApplicationHelper

  def visible?
    sub_list_view_screen? && super
  end
end
