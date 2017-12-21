module HasMonitoringManagerMixin
  extend ActiveSupport::Concern

  def ensure_monitoring_manager_with_params
    if monitoring_manager.nil?
      build_monitoring_manager(:parent_manager  => self,
                               :name            => "#{name} Monitoring Manager",
                               :zone_id         => zone_id,
                               :provider_region => provider_region)
    end

    monitoring_manager
  end

  def endpoint_created(role)
    if role == "prometheus_alerts" && monitoring_manager.nil?
      monitoring_manager = ensure_monitoring_manager_with_params
      monitoring_manager.save
    end
  end

  def endpoint_destroyed(role)
    if role == "prometheus_alerts" && monitoring_manager.present?
      # TODO: if someone deletes the alerts endpoint and then quickly readds it they can end up without a manager.
      monitoring_manager.destroy_queue
    end
  end
end
