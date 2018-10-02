module ManageIQ::Providers
  class CloudManager < BaseManager
    require_nested :AuthKeyPair
    require_nested :RefreshParser
    require_nested :Template
    require_nested :Provision
    require_nested :ProvisionWorkflow
    require_nested :Vm
    require_nested :OrchestrationStack
    require_nested :VmOrTemplate

    class << model_name
      define_method(:route_key) { "ems_clouds" }
      define_method(:singular_route_key) { "ems_cloud" }
    end

    has_many :availability_zones,            :foreign_key => :ems_id, :dependent => :destroy
    has_many :flavors,                       :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_database_flavors,        :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_tenants,                 :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_resource_quotas,         :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volumes,                 :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_types,            :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_backups,          :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_snapshots,        :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_object_store_containers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_object_store_objects,    :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_services,                :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_databases,               :foreign_key => :ems_id, :dependent => :destroy
    has_many :key_pairs,                     :class_name  => "AuthPrivateKey", :as => :resource, :dependent => :destroy
    has_many :host_aggregates,               :foreign_key => :ems_id, :dependent => :destroy
    has_one  :source_tenant, :as => :source, :class_name  => 'Tenant'
    has_many :vm_and_template_labels,        :through     => :vms_and_templates, :source => :labels
    # Only taggings mapped from labels, excluding user-assigned tags.
    has_many :vm_and_template_taggings,      -> { joins(:tag).merge(Tag.controlled_by_mapping) },
                                             :through     => :vms_and_templates, :source => :taggings

    validates_presence_of :zone

    include HasNetworkManagerMixin
    include HasManyOrchestrationStackMixin

    # Development helper method for Rails console for opening a browser to the EMS.
    #
    # This method is NOT meant to be called from production code.
    def open_browser
      raise NotImplementedError unless Rails.env.development?
      require 'util/miq-system'
      MiqSystem.open_browser(browser_url)
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

    def sync_cloud_tenants_with_tenants
      return unless supports_cloud_tenant_mapping?
      sync_root_tenant
      sync_tenants
      sync_deleted_cloud_tenants
    end

    def sync_tenants
      reload

      _log.info("Syncing CloudTenant with Tenants...")

      CloudTenant.with_ext_management_system(id).walk_tree do |cloud_tenant, _|
        cloud_tenant_description = cloud_tenant.description.blank? ? cloud_tenant.name : cloud_tenant.description
        tenant_params = {:name => cloud_tenant.name, :description => cloud_tenant_description, :source => cloud_tenant}

        tenant_parent = cloud_tenant.parent.try(:source_tenant) || source_tenant

        if cloud_tenant.source_tenant
          cloud_tenant.update_source_tenant(tenant_params)
        elsif existing_source_tenant = Tenant.descendants_of(tenant_parent).find_by(:name => tenant_params[:name])
          _log.info("CloudTenant #{cloud_tenant.name} has orphaned tenant #{existing_source_tenant.name}")
          cloud_tenant.source_tenant = existing_source_tenant
          tenant_params[:parent] = tenant_parent
          cloud_tenant.update_source_tenant(tenant_params)
        else
          _log.info("CloudTenant #{cloud_tenant.name} has no tenant")
          _log.info("Creating Tenant with parameters: #{tenant_params.inspect}")

          # first level of CloudTenants does not have parents - in that case
          # source_tenant from EmsCloud is used - this is tenant which is representing
          # provider (EmsCloud)
          # if it is not first level of cloud tenant
          # there is existing parent of CloudTenant and his related tenant is taken
          _log.info("and with parent #{tenant_parent.name}")
          tenant_params[:parent] = tenant_parent
          cloud_tenant.source_tenant = Tenant.new(tenant_params)
          _log.info("New Tenant #{cloud_tenant.source_tenant.name} created")
        end

        cloud_tenant.update_source_tenant_associations
        cloud_tenant.save!
        _log.info("CloudTenant #{cloud_tenant.name} saved")
      end
    end

    def sync_deleted_cloud_tenants
      return unless source_tenant

      source_tenant.descendants.each do |tenant|
        next if tenant.source

        if tenant.parent == source_tenant # tenant is already under provider's tenant
          _log.info("Setting source_id and source_type to nil for #{tenant.name} under provider's tenant #{source_tenant.name}")
          tenant.update_attributes(:source_id => nil, :source_type => nil)
          next
        end

        # move tenant under the provider's tenant
        _log.info("Moving out #{tenant.name} under provider's tenant #{source_tenant.name}")
        tenant.update_attributes(:parent => source_tenant, :source_id => nil, :source_type => nil)
      end
    end

    def sync_root_tenant
      ems_tenant = source_tenant || Tenant.new(:parent => tenant, :source => self)

      ems_tenant_name = "#{self.class.description} Cloud Provider #{name}"

      ems_tenant.update_attributes!(:name => ems_tenant_name, :description => ems_tenant_name)
    end

    def create_cloud_tenant(options)
      CloudTenant.create_cloud_tenant(self, options)
    end

    def self.display_name(number = 1)
      n_('Cloud Manager', 'Cloud Managers', number)
    end
  end
end
