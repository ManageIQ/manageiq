class ApplicationHelper::Button::HostScan < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.is_scannable?
  end

  def disabled?
    @record.is_scannable_now_error_message unless @record.is_scannable_now?
  end
end
