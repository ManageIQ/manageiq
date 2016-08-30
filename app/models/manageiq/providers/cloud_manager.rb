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
    has_many :host_aggregates,               :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_networks,                :through     => :network_manager
    has_many :security_groups,               :through     => :network_manager

    has_one  :source_tenant, :as => :source, :class_name => 'Tenant'

    validates_presence_of :zone

    include HasNetworkManagerMixin
    include HasManyOrchestrationStackMixin

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

    def sync_cloud_tenants_with_tenants
      return unless supports_cloud_tenants?
      sync_root_tenant
      sync_tenants
    end

    def sync_tenants
      reload

      $log.info("Syncing CloudTenant with Tenants...")

      CloudTenant.with_ext_management_system(id).walk_tree do |cloud_tenant, _|
        tenant_params = {:name => cloud_tenant.name, :description => cloud_tenant.name}

        if cloud_tenant.source_tenant
          $log.info("CloudTenant #{cloud_tenant.name} has tenant #{cloud_tenant.source_tenant.name}")
          $log.info("Updating Tenant #{cloud_tenant.source_tenant.name} with parameters: #{tenant_params.inspect}")
          cloud_tenant.source_tenant.update(tenant_params)
        else
          $log.info("CloudTenant #{cloud_tenant.name} has no tenant")
          $log.info("Creating Tenant with parameters: #{tenant_params.inspect}")

          # first level of CloudTenants does not have parents - in that case
          # source_tenant from EmsCloud is used - this is tenant which is representing
          # provider (EmsCloud)
          # if it is not first level of cloud tenant
          # there is existing parent of CloudTenant and his related tenant is taken
          tenant_parent = cloud_tenant.parent.try(:source_tenant) || source_tenant
          $log.info("and with parent #{tenant_parent.name}")
          tenant_params[:parent] = tenant_parent
          tenant_params[:source] = cloud_tenant
          cloud_tenant.source_tenant = Tenant.new(tenant_params)
          $log.info("New Tenant #{cloud_tenant.source_tenant.name} created")
        end

        cloud_tenant.update_source_tenant_associations
        cloud_tenant.save!
        $log.info("CloudTenant #{cloud_tenant.name} saved")
      end
    end

    def sync_root_tenant
      ems_tenant = source_tenant || Tenant.new(:parent => Tenant.root_tenant, :source => self)

      ems_tenant_name = "#{self.class.description} Cloud Provider #{name}"

      ems_tenant.update_attributes!(:name => ems_tenant_name, :description => ems_tenant_name)
    end
  end
end
