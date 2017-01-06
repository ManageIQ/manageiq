#
#

class ManageIQ::Providers::StorageManager::CinderManager < ManageIQ::Providers::StorageManager
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher

  include ManageIQ::Providers::StorageManager::BlockMixin

  # Auth and endpoints delegations, editing of this type of manager must be disabled
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :authentications,
           :authentication_for_summary,
           :zone,
           :cinder_service,
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

  supports :cinder_service do
    if parent_manager
      unsupported_reason_add(:cinder_service, parent_manager.unsupported_reason(:cinder_service)) unless
        parent_manager.supports_cinder_service?
    else
      unsupported_reason_add(:cinder_service, _('no parent_manager to ems'))
    end
  end

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
    ManageIQ::Providers::StorageManager::CinderManager::EventCatcher
  end
end
