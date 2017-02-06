module ManageIQ::Providers
  class PhysicalInfraManager < BaseManager
    class << model_name
      define_method(:route_key) { "ems_physical_infras" }
      define_method(:singular_route_key) { "ems_physical_infra" }
    end

    def self.ems_type
      @ems_type ||= "physical_infra_manager".freeze
    end

    def self.description
      @description ||= "PhysicalInfraManager".freeze
    end

    def validate_authentication_status
      {:available => true, :message => nil}
    end
  end
end
