class ApplicationHelper::Button::EmsCloudRecheckAuthStatus < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:authentication_status)
  end
end
