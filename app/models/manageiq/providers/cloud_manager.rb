module ManageIQ::Providers
  class CloudManager < BaseManager
    require_dependency 'manageiq/providers/cloud_manager/auth_key_pair'
    require_dependency 'manageiq/providers/cloud_manager/refresh_parser'
    require_dependency 'manageiq/providers/cloud_manager/template'
    require_dependency 'manageiq/providers/cloud_manager/provision'
    require_dependency 'manageiq/providers/cloud_manager/provision_workflow'
    require_dependency 'manageiq/providers/cloud_manager/vm'

    class << model_name
      define_method(:route_key) { "ems_clouds" }
      define_method(:singular_route_key) { "ems_cloud" }
    end

    has_many :availability_zones,            :foreign_key => :ems_id, :dependent => :destroy
    has_many :flavors,                       :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_tenants,                 :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_resource_quotas,         :foreign_key => :ems_id, :dependent => :destroy
    has_many :floating_ips,                  :foreign_key => :ems_id, :dependent => :destroy
    has_many :security_groups,               :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_networks,                :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_subnets,                 :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_ports,                 :foreign_key => :ems_id, :dependent => :destroy
    has_many :network_routers,               :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volumes,                 :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_volume_snapshots,        :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_object_store_containers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :cloud_object_store_objects,    :foreign_key => :ems_id, :dependent => :destroy
    has_many :key_pairs,                     :class_name  => "AuthPrivateKey", :as => :resource, :dependent => :destroy

    alias_method :all_cloud_networks, :cloud_networks

    validates_presence_of :zone
    include HasManyOrchestrationStackMixin

    # Development helper method for Rails console for opening a browser to the EMS.
    #
    # This method is NOT meant to be called from production code.
    def open_browser
      raise NotImplementedError unless Rails.env.development?
      require 'util/miq-system'
      MiqSystem.open_browser(browser_url)
    end
  end
end
