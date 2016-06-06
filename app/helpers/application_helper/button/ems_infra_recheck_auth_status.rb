class ApplicationHelper::Button::EmsInfraRecheckAuthStatus < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:authentication_status)
  end
end
