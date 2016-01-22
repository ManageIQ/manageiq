class MigrateOldConfigurationSettings < ActiveRecord::Migration
  class Configuration < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    serialize :settings, Hash
  end

  def up
    update_methods = private_methods(false)

    say_with_time("Migrating old configuration settings") do
      Configuration.where(:typ => "vmdb").each do |config|
        hash = config.settings.deep_symbolize_keys
        update_methods.each { |m| send(m, hash) }
        config.update_attributes!(:settings => hash)
      end
    end
  end

  private

  def update_old_perf_processor_worker_settings!(config)
    old_path = %i(workers worker_base queue_worker_base perf_processor_worker)
    new_path = %i(workers worker_base queue_worker_base ems_metrics_processor_worker)

    settings = config.fetch_path(*old_path)
    return if settings.nil?

    settings = {:defaults => settings}

    config.delete_path(*old_path)
    config.store_path(new_path, settings)
  end

  def update_old_perf_collector_worker_settings!(config)
    old_path = %i(workers worker_base queue_worker_base perf_collector_worker)
    new_path = %i(workers worker_base queue_worker_base ems_metrics_collector_worker)

    settings = config.fetch_path(*old_path)
    return if settings.nil?

    keys = %i(
      ems_metrics_collector_worker_amazon
      ems_metrics_collector_worker_redhat
      ems_metrics_collector_worker_vmware
      ems_metrics_collector_worker_openstack
      ems_metrics_collector_worker_kubernetes
    )
    keys.each { |key| settings.delete(key) }
    settings = {:defaults => settings}

    config.delete_path(*old_path)
    config.store_path(new_path, settings)
  end

  def update_old_ui_worker_settings!(config)
    return if config.fetch_path(:workers, :worker_base, :ui_worker)

    roles = config.fetch_path(:server, :role).split(',')
    return if roles.include?('user_interface')

    roles << 'user_interface'
    config.store_path(:server, :role, roles.join(','))
  end

  def update_old_web_service_worker_settings!(config)
    return if config.fetch_path(:workers, :worker_base, :web_service_worker)

    roles = config.fetch_path(:server, :role).split(',')
    return if roles.include?('web_services')

    roles << 'web_services'
    config.store_path(:server, :role, roles.join(','))
  end

  def update_old_event_catcher_settings!(config)
    path = %i(workers worker_base event_catcher)

    settings = config.fetch_path(*path)
    return if settings.try(:key?, :defaults)

    keys = %i(
      event_catcher_redhat
      event_catcher_vmware
      event_catcher_openstack
    )
    keys.each { |key| settings.delete(key) }
    settings = {:defaults => settings}

    config.store_path(path, settings)
  end

  def update_old_ems_refresh_worker_settings!(config)
    path = %i(workers worker_base queue_worker_base ems_refresh_worker)

    settings = config.fetch_path(*path)
    return if settings.try(:key?, :defaults)

    keys = %i(
      ems_refresh_worker_ansible_tower_configuration
      ems_refresh_worker_atomic
      ems_refresh_worker_atomic_enterprise
      ems_refresh_worker_azure
      ems_refresh_worker_ec2
      ems_refresh_worker_foreman_configuration
      ems_refresh_worker_foreman_provisioning
      ems_refresh_worker_gce
      ems_refresh_worker_kubernetes
      ems_refresh_worker_openshift
      ems_refresh_worker_openshift_enterprise
      ems_refresh_worker_openstack
      ems_refresh_worker_openstack_infra
      ems_refresh_worker_rhevm
      ems_refresh_worker_scvmm
      ems_refresh_worker_vmwarews
    )
    keys.each { |key| settings.delete(key) }
    settings = {:defaults => settings}

    config.store_path(path, settings)
  end
end
