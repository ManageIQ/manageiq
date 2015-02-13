module PerEmsTypeWorkerMixin
  extend ActiveSupport::Concern

  included do
    self.check_for_minimal_role = false
  end

  module ClassMethods
    def workers
      return 0 unless self.any_valid_ems_in_zone?
      return (self.has_minimal_env_option? ? 1 : 0) if MiqServer.minimal_env?
      return self.workers_configured_count
    end

    def ems_class
      ExtManagementSystem
    end

    def emses_in_zone
      self.ems_class.where(:zone_id => MiqServer.my_server.zone.id)
    end

    def any_valid_ems_in_zone?
      self.emses_in_zone.any?(&:authentication_status_ok?)
    end
  end
end
