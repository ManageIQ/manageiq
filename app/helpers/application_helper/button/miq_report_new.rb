class ApplicationHelper::Button::MiqReportNew < ApplicationHelper::Button::MiqReportAction
  include ApplicationHelper::Button::Mixins::SubListViewScreenMixin

  def visible?
    sub_list_view_screen? && super
  end
end
