module PerEmsTypeWorkerMixin
  extend ActiveSupport::Concern

  included do
    self.check_for_minimal_role = false
    @workers = lambda do
      return 0 unless self.any_valid_ems_in_zone?
      workers_configured_count
    end
  end

  module ClassMethods
    def ems_class
      ExtManagementSystem
    end

    def emses_in_zone
      ems_class.where(:zone_id => MiqServer.my_server.zone.id)
    end

    def any_valid_ems_in_zone?
      emses_in_zone.any?(&:authentication_status_ok?)
    end
  end
end
