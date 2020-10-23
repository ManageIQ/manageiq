module HasMonitoringManagerMixin
  extend ActiveSupport::Concern

  def monitoring_endpoint_created(role)
    if role == "prometheus_alerts" && monitoring_manager.nil?
      monitoring_manager = ensure_monitoring_manager
      monitoring_manager.save
    end
  end

  def monitoring_endpoint_destroyed(role)
    if role == "prometheus_alerts" && monitoring_manager.present?
      # TODO: if someone deletes the alerts endpoint and then quickly readds it they can end up without a manager.
      monitoring_manager.destroy_queue
    end
  end

  private

  def ensure_monitoring_manager
    monitoring_manager ||= propagate_child_attributes(build_monitoring_manager(:name => "#{name} Monitoring Manager"))
  end
end
