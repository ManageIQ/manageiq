#
#
# TODO (hsong) Storage Manager
#
#


class ManageIQ::Providers::StorageManager::SwiftStorageManager < ManageIQ::Providers::StorageManager 
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher


  # Auth and endpoints delegations, editing of this type of manager must be disabled
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :authentications,
           :authentication_for_summary,
           :zone,
           :openstack_handle,
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

  def self.hostname_required?
    false
  end

  def self.ems_type
    @ems_type ||= "swift_storage".freeze
  end

  def self.description
    @description ||= "Swift Storage".freeze
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
    ManageIQ::Providers::StorageManager::SwiftStorageManager::EventCatcher
  end
end
