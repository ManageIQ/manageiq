module ManageIQ::Providers
  class MonitoringManager < BaseManager
    def self.ems_type
      "monitoring".freeze
    end

    def self.description
      "Monitoring Manager".freeze
    end
  end
end
