class ManageIQ::Providers::Openstack::InfraManager < ::EmsInfra
  require_nested :AuthKeyPair
  require_nested :EmsCluster
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Host
  require_nested :HostServiceGroup
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :OrchestrationStack
  require_nested :Refresher
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Template

  include ManageIQ::Providers::Openstack::ManagerMixin
  include HasManyOrchestrationStackMixin
  include HasManyCloudNetworksMixin

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
    self.provider = ManageIQ::Providers::Openstack::Provider.find_by_name(name) unless provider

    attributes = {:name => name, :zone => zone}
    if provider
      provider.update_attributes!(attributes)
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

  def supports_api_version?
    true
  end

  def supports_security_protocol?
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
