class ApplicationHelper::Button::EmsNetworkNew < ApplicationHelper::Button::EmsNetwork
  include ApplicationHelper::Button::Mixins::SubListViewScreenMixin

  def visible?
    sub_list_view_screen? && super
  end
end
