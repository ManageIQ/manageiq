class ManageIQ::Providers::StorageManager::SwiftManager < ManageIQ::Providers::StorageManager
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher

  has_many :cloud_object_store_containers, :foreign_key => :ems_id, :dependent => :destroy
  has_many :cloud_object_store_objects,    :foreign_key => :ems_id, :dependent => :destroy

  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok,
           :authentications,
           :authentication_for_summary,
           :zone,
           :swift_handle,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :address,
           :ip_address,
           :hostname,
           :default_endpoint,
           :endpoints,
           :to        => :parent_manager,
           :allow_nil => true

  supports :swift_service do
    if self.parent_manager
      unsupported_reason_add(:swift_service, self.parent_manager.unsupported_reason(:swift_service)) unless
        self.parent_manager.supports_swift_service?
    else
      unsupported_reason_add(:swift_service, _('no parent_manager to ems'))
    end
  end

  def self.hostname_required?
    false
  end

  def self.ems_type
    @ems_type ||= "swift_".freeze
  end

  def self.description
    @description ||= "Swift ".freeze
  end

  def get_swift_service
    self.parent_manager.nil? ? nil : connect(:service => "Storage")
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

  def self.event_monitor_class
    ManageIQ::Providers::StorageManager::SwiftManager::EventCatcher
  end
end
