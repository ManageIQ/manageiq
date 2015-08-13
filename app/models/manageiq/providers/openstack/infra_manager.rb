class ManageIQ::Providers::Openstack::InfraManager < ::EmsInfra
  require_dependency 'manageiq/providers/openstack/infra_manager/auth_key_pair'
  require_dependency 'manageiq/providers/openstack/infra_manager/ems_cluster'
  require_dependency 'manageiq/providers/openstack/infra_manager/event_catcher'
  require_dependency 'manageiq/providers/openstack/infra_manager/event_parser'
  require_dependency 'manageiq/providers/openstack/infra_manager/host'
  require_dependency 'manageiq/providers/openstack/infra_manager/host_service_group'
  require_dependency 'manageiq/providers/openstack/infra_manager/metrics_collector_worker'
  require_dependency 'manageiq/providers/openstack/infra_manager/orchestration_stack'
  require_dependency 'manageiq/providers/openstack/infra_manager/refresher'
  require_dependency 'manageiq/providers/openstack/infra_manager/refresh_parser'
  require_dependency 'manageiq/providers/openstack/infra_manager/refresh_worker'

  include ManageIQ::Providers::Openstack::ManagerMixin
  include HasManyOrchestrationStackMixin

  before_save :ensure_parent_provider
  before_destroy :destroy_parent_provider

  def cloud_tenants
    CloudTenant.where(:ems_id => provider.try(:cloud_ems).try(:collect, &:id).try(:uniq))
  end

  def availability_zones
    AvailabilityZone.where(:ems_id => provider.try(:cloud_ems).try(:collect, &:id).try(:uniq))
  end

  def ensure_parent_provider
    # TODO(lsmola) this might move to a general management of Providers, but for now, we will ensure, every
    # EmsOpenstackInfra has associated a Provider. This relation will serve for relating EmsOpenstackInfra
    # to possible many EmsOpenstacks deployed through EmsOpenstackInfra

    # Name of the provider needs to be unique, get provider if there is one like that
    self.provider = ManageIQ::Providers::Openstack::Provider.find_by_name(name) unless self.provider

    attributes = {:name => name, :zone => zone}
    if self.provider
      self.provider.update_attributes!(attributes)
    else
      self.provider = ManageIQ::Providers::Openstack::Provider.create!(attributes)
    end
  end

  def destroy_parent_provider
    provider.try(:destroy)
  end

  def self.ems_type
    @ems_type ||= "openstack_infra".freeze
  end

  def self.description
    @description ||= "OpenStack Platform Director".freeze
  end

  def supports_port?
    true
  end

  def supported_auth_types
    %w(default amqp ssh_keypair)
  end

  def supported_auth_attributes
    %w(userid password auth_key)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openstack::InfraManager::EventCatcher
  end
end
