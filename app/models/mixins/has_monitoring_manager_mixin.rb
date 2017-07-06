module HasMonitoringManagerMixin
  extend ActiveSupport::Concern

  private

  def ensure_monitoring_manager
    # monitoring_manager should be defined by child classes.
    if try(:monitoring_manager_needed?)
      build_monitoring_manager(:parent_manager => self)
      monitoring_manager.name = "#{name} Monitoring Manager"
    end
    ensure_monitoring_manager_properties
  end

  def ensure_monitoring_manager_properties
    if monitoring_manager
      monitoring_manager.zone_id = zone_id
      monitoring_manager.provider_region = provider_region
    end
  end
end
