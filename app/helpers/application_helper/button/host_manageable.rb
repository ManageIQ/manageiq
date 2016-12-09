class ApplicationHelper::Button::HostManageable < ApplicationHelper::Button::HostIntrospectProvide
  needs :@record

  def visible?
    proper_record? && !host_manageable?
  end
end
