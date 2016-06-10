class ApplicationHelper::Button::EmsContainerRecheckAuthStatus < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:authentication_status)
  end
end
