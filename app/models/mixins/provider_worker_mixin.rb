module ProviderWorkerMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def ems_class
      module_parent
    end

    def all_ems_in_zone
      ems_class.where(:zone_id => MiqServer.my_server.zone.id)
    end

    def all_valid_ems_in_zone
      all_ems_in_zone.select { |e| e.enabled && e.provider_authentication_status_ok? }
    end

    def any_valid_ems_in_zone?
      all_valid_ems_in_zone.any?
    end

    def service_base_name
      "manageiq-providers-#{minimal_class_name.underscore.tr("/", "_")}"
    end
  end
end
