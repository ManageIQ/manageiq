class ApplicationHelper::Button::CustomizationTemplateNew < ApplicationHelper::Button::CustomizationTemplate
  include ApplicationHelper::Button::Mixins::SubListViewScreenMixin

  def visible?
    sub_list_view_screen? && !system?
  end
end
