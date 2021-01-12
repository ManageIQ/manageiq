class ManageIQ::Providers::StorageManager::SwiftManager < ManageIQ::Providers::StorageManager
  require_nested :Refresher

  include ManageIQ::Providers::StorageManager::ObjectMixin

  def self.hostname_required?
    false
  end

  def self.ems_type
    @ems_type ||= "swift".freeze
  end

  def self.description
    @description ||= "Swift ".freeze
  end

  def description
    @description ||= "Swift ".freeze
  end

  def name
    "#{parent_manager.try(:name)} Swift Manager"
  end

  def supports_api_version?
    true
  end

  def supports_security_protocol?
    true
  end

  def supports_provider_id?
    true
  end

  def allow_targeted_refresh?
    false
  end

  def self.display_name(number = 1)
    n_('Storage Manager (Swift)', 'Storage Managers (Swift)', number)
  end
end
