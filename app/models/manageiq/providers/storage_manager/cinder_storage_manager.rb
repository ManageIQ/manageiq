#
#
# TODO (hsong) Storage Manager
#
#


class ManageIQ::Providers::StorageManager::CinderStorageManager < ManageIQ::Providers::StorageManager 
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher

  has_many :cloud_volumes,                 :foreign_key => :ems_id, :dependent => :destroy
  has_many :cloud_volume_snapshots,        :foreign_key => :ems_id, :dependent => :destroy
  has_many :cloud_volume_backups,          :foreign_key => :ems_id, :dependent => :destroy

  # Auth and endpoints delegations, editing of this type of manager must be disabled
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :authentications,
           :authentication_for_summary,
           :zone,
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

  supports :cinder_storage do
    if self.parent_manager
      unsupported_reason_add(:cinder_storage, self.parent_manager.unsupported_reason(:cinder_storage)) unless 
        self.parent_manager.supports_cinder_serive?
    else
      unsupported_reason_add(:cinder_storage, _('no parent_manager to ems'))
    end
  end


  def self.hostname_required?
    false
  end

  def self.ems_type
    @ems_type ||= "cinder_storage".freeze
  end

  def self.description
    @description ||= "Cinder Storage".freeze
  end

  def get_cinder_service
    # TODO: place to handle the case without parent_manager
    self.parent_manager.nil? ? nil : connect(:service => "Volume")
  end

  #
  # TODO: add logic to check from parent_manager
  #
  def supports_cinder_storage
    true
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
    ManageIQ::Providers::StorageManager::CinderStorageManager::EventCatcher
  end
end
