module ManageIQ::Providers
  class PhysicalInfraManager < BaseManager
    class << model_name
      define_method(:route_key) { "ems_physical_infras" }
      define_method(:singular_route_key) { "ems_physical_infra" }
    end
  end
end
