class ApplicationHelper::Button::TimelineDownload < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = _("Choose a Timeline from the menus on the left.") if disabled?
  end

  def visible?
    @report
  end

  def disabled?
    @record.nil?
  end
end
