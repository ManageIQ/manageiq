class ApplicationHelper::Button::MiqTaskCanceljob < ApplicationHelper::Button::ButtonWithoutRbacCheck
  def visible?
    !%w(all_tasks all_ui_tasks).include?(@layout)
  end
end
