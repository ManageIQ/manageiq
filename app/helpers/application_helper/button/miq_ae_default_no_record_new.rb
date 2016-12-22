class ApplicationHelper::Button::MiqAeDefaultNoRecordNew < ApplicationHelper::Button::MiqAeDefault
  include ApplicationHelper::Button::Mixins::SubListViewScreenMixin

  def visible?
    sub_list_view_screen?
  end
end
