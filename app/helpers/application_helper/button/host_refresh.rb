class ApplicationHelper::Button::HostRefresh < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.is_refreshable?
  end

  def disabled?
    @record.is_refreshable_now_error_message unless @record.is_refreshable_now?
  end
end
