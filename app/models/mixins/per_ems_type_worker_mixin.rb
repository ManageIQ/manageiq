module PerEmsTypeWorkerMixin
  extend ActiveSupport::Concern

  included do
    self.check_for_minimal_role = false
  end

  module ClassMethods
    def workers
      return 0 unless any_valid_ems_in_zone?

      super
    end

    def ems_class
      parent
    end

    def emses_in_zone
      ems_class.where(:zone_id => MiqServer.my_server.zone.id)
    end

    def any_valid_ems_in_zone?
      emses_in_zone.any?(&:authentication_status_ok?)
    end
  end
end
