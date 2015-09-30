
class ManageIQ::Providers::Openstack::InfraManager < ::EmsInfra
  require_dependency 'manageiq/providers/openstack/infra_manager/auth_key_pair'
  require_dependency 'manageiq/providers/openstack/infra_manager/ems_cluster'
  require_dependency 'manageiq/providers/openstack/infra_manager/event_catcher'
  require_dependency 'manageiq/providers/openstack/infra_manager/event_parser'
  require_dependency 'manageiq/providers/openstack/infra_manager/host'
  require_dependency 'manageiq/providers/openstack/infra_manager/host_service_group'
  require_dependency 'manageiq/providers/openstack/infra_manager/metrics_capture'
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

  def clouds
    overclouds = ManageIQ::Providers::Openstack::CloudManager.find(:all, :conditions => ["id != ? and provider_id = ?", id, provider_id])
  end

  #
  # Statistics
  #

  def cloud_cinder_disk_usage
    cinder_used = 0
    clouds.each do |cloud|
      cinder_used += cloud.cinder_disk_usage
    end
    cinder_used
  end

  def cloud_swift_disk_usage
    replicas = OrchestrationStackParameter.joins(:stack).where("orchestration_stacks.ems_id = ? AND orchestration_stack_parameters.name = 'SwiftReplicas'", id).first.value.to_i
    object_storage_count = OrchestrationStackParameter.joins(:stack).where("orchestration_stacks.ems_id = ? AND orchestration_stack_parameters.name = 'ObjectStorageCount'", id).first.value.to_i
    # The number of replicas depends on what was configured in swift as replicas
    # and the number of object storage nodes deployed. The actual number of replicas
    # is the minimum between the configured replicas and object storage nodes.
    # Note the controller node currently also serves as a swift storage node. So
    # this doesn't reflect true disk usage over the entire overcloud.
    actual_replicas = [replicas, object_storage_count].sort.first
    swift_used = 0
    clouds.each do |cloud|
      swift_used += cloud.swift_disk_usage(actual_replicas)
    end
    swift_used
  end
end
