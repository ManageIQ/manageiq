class ApplicationHelper::Button::VolumeBackupCreate < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.unsupported_reason(:cloud_volume_backup_create) if disabled?
  end

  def disabled?
    !@record.supports?(:cloud_volume_backup_create)
  end
end
