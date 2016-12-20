class ApplicationHelper::Button::ButtonNewDiscover < ApplicationHelper::Button::Basic
  include ApplicationHelper::Button::Mixins::SubListViewScreenMixin

  def visible?
    sub_list_view_screen?
  end
end
