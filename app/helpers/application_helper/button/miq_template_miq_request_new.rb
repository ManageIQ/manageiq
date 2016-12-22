class ApplicationHelper::Button::MiqTemplateMiqRequestNew < ApplicationHelper::Button::GenericFeatureButtonWithDisable
  include ApplicationHelper::Button::Mixins::SubListViewScreenMixin

  def visible?
    sub_list_view_screen? && super
  end
end
