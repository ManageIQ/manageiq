class ApplicationHelper::Button::TimelineDownload < ApplicationHelper::Button::Basic
  def visible?
    @report
  end

  def disabled?
    @error_message = _('Choose a Timeline from the menus on the left.') if @record.nil?
    @error_message.present?
  end
end
