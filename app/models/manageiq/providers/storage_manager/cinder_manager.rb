class ManageIQ::Providers::StorageManager::CinderManager < ManageIQ::Providers::StorageManager
  require_nested :Refresher

  include ManageIQ::Providers::StorageManager::BlockMixin

  def self.hostname_required?
    false
  end

  def self.ems_type
    @ems_type ||= "cinder".freeze
  end

  def self.description
    @description ||= "Cinder ".freeze
  end

  def description
    @description ||= "Cinder ".freeze
  end

  def name
    "#{parent_manager.try(:name)} Cinder Manager"
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

  def self.display_name(number = 1)
    n_('Storage Manager (Cinder)', 'Storage Managers (Cinder)', number)
  end
end
