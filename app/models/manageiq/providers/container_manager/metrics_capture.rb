class ManageIQ::Providers::ContainerManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  def capture_ems_targets(_options = {})
    return [] unless ems.supports_metrics?

    MiqPreloader.preload([ems], :container_nodes => :tags, :container_groups => [:tags, :containers => :tags])

    with_archived(ems.all_container_nodes) + with_archived(ems.all_container_groups) + with_archived(ems.all_containers)
  end

  private

  def with_archived(scope)
    # We will look also for freshly archived entities, if the entity was short-lived or even sub-hour
    archived_from = Metric::Targets.targets_archived_from
    scope.where(:deleted_on => nil).or(scope.where(:deleted_on => (archived_from..Time.now.utc)))
  end
end
