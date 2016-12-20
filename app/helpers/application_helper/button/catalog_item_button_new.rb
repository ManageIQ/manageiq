class ApplicationHelper::Button::CatalogItemButtonNew < ApplicationHelper::Button::CatalogItemButton
  include ApplicationHelper::Button::Mixins::SubListViewScreenMixin

  def visible?
    sub_list_view_screen? && super
  end
end
