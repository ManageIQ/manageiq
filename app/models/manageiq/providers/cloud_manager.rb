module ManageIQ::Providers
  class CloudManager < BaseManager
    require_nested :AuthKeyPair
    require_nested :RefreshParser
    require_nested :Template
    require_nested :Provision
    require_nested :ProvisionWorkflow
    require_nested :Vm
    require_nested :OrchestrationStack

    class << model_name
      define_method(:route_key) { "ems_clouds" }
      define_method(:singular_route_key) { "ems_cloud" }
    end

    has_many :arbitration_profiles,          :foreign_key => :ems_id, :dependent => :destroy
    has_many :availability_zones,            :foreign_key => :ems_id, :dependent => :destroy
    has_many :flavors,                       :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_database_flavors,        :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_tenants,                 :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_resource_quotas,         :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volumes,                 :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_snapshots,        :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_object_store_containers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_object_store_objects,    :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_services,                :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_databases,               :foreign_key => :ems_id, :dependent => :destroy
    has_many :key_pairs,                     :class_name  => "AuthPrivateKey", :as => :resource, :dependent => :destroy

    validates_presence_of :zone

    include HasNetworkManagerMixin
    include HasManyOrchestrationStackMixin
    include CloudTenantMixin

    supports_not :discovery

    # Development helper method for Rails console for opening a browser to the EMS.
    #
    # This method is NOT meant to be called from production code.
    def open_browser
      raise NotImplementedError unless Rails.env.development?
      require 'util/miq-system'
      MiqSystem.open_browser(browser_url)
    end

    def validate_timeline
      {:available => true, :message => nil}
    end

    def validate_authentication_status
      {:available => true, :message => nil}
    end

    def stop_event_monitor_queue_on_credential_change
      if event_monitor_class && !self.new_record? && self.credentials_changed?
        _log.info("EMS: [#{name}], Credentials have changed, stopping Event Monitor.  It will be restarted by the WorkerMonitor.")
        stop_event_monitor_queue
        network_manager.stop_event_monitor_queue if respond_to?(:network_manager) && network_manager
      end
    end

    def supports_cloud_tenants?
      false
    end
  end
end
