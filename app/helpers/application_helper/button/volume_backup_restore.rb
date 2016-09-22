class ApplicationHelper::Button::VolumeBackupRestore < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.unsupported_reason(:cloud_volume_backup_restore) if disabled?
  end

  def disabled?
    !@record.supports?(:cloud_volume_backup_restore)
  end
end
