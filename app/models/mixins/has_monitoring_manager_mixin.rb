module HasMonitoringManagerMixin
  extend ActiveSupport::Concern

  private

  def ensure_monitoring_manager
    # monitoring_manager should be defined by child classes.
    if monitoring_manager_needed? && monitoring_manager.nil?
      build_monitoring_manager(:parent_manager => self)
      monitoring_manager.name = "#{name} Monitoring Manager"
      monitoring_manager.zone_id = zone_id
      monitoring_manager.provider_region = provider_region
    elsif !monitoring_manager_needed? && monitoring_manager.present?
      # TODO: if someone deletes the alerts endpoint and then quickly readds it they can end up without a manager.
      monitoring_manager.delete_queue
    end
  end
end
