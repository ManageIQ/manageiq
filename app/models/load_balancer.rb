class LoadBalancer < ApplicationRecord
  include NewWithTypeStiMixin
  include AsyncDeleteMixin
  include ProcessTasksMixin
  include RetirementMixin
  include TenantIdentityMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant

  has_many :load_balancer_health_checks
  has_many :load_balancer_listeners
  has_many :load_balancer_pools, :through => :load_balancer_listeners
  has_many :load_balancer_pool_members, -> { distinct }, :through => :load_balancer_pools

  has_many :network_ports, :as => :device
  has_many :cloud_subnet_network_ports, :through => :network_ports
  has_many :cloud_subnets, :through => :cloud_subnet_network_ports
  has_many :floating_ips, :through => :network_ports, :source => :floating_ips
  has_many :security_groups, -> { distinct }, :through => :network_ports

  has_many :vms, -> { distinct }, :through => :load_balancer_pool_members
  has_many :resource_groups, -> { distinct }, :through => :load_balancer_pool_members

  has_many :service_resources, :as => :resource
  has_many :direct_services, :through => :service_resources, :source => :service

  virtual_has_one :direct_service, :class_name => 'Service'
  virtual_has_one :service, :class_name => 'Service'

  virtual_total :total_vms, :vms, :uses => :vms

  def direct_service
    direct_services.first
  end

  def service
    direct_service.try(:root_service)
  end

  def self.create_load_balancer(load_balancer_manager, load_balancer_name, options = {})
    klass = load_balancer_class_factory(load_balancer_manager)
    ems_ref = klass.raw_create_load_balancer(load_balancer_manager,
                                             load_balancer_name,
                                             options)
    tenant = CloudTenant.find_by(:name => options[:tenant_name], :ems_id => load_balancer_manager.id)

    klass.create(:name                  => load_balancer_name,
                 :ems_ref               => ems_ref,
                 :ext_management_system => load_balancer_manager,
                 :cloud_tenant          => tenant)
  end

  def self.load_balancer_class_factory(load_balancer_manager)
    "#{load_balancer_manager.class.name}::LoadBalancer".constantize
  end

  def raw_update_load_balancer(_options = {})
    raise NotImplementedError, _("raw_update_load_balancer must be implemented in a subclass")
  end

  def update_load_balancer(options = {})
    raw_update_load_balancer(options)
  end

  def raw_delete_load_balancer
    raise NotImplementedError, _("raw_delete_load_balancer must be implemented in a subclass")
  end

  def delete_load_balancer
    raw_delete_load_balancer
  end

  def raw_status
    raise NotImplementedError, _("raw_status must be implemented in a subclass")
  end

  def raw_exists?
    raise NotImplementedError, _("raw_exists must be implemented in a subclass")
  end
end
