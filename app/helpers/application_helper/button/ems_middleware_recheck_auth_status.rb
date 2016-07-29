class ApplicationHelper::Button::EmsMiddlewareRecheckAuthStatus < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:authentication_status)
  end
end
