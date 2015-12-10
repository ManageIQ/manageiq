class ApplicationHelper::Button::CollectLogs < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @record.try(:log_file_depot).try(:requires_support_case?)
      self[:prompt] = true
    end
  end
end
