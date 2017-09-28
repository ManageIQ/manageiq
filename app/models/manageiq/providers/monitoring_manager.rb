module ManageIQ::Providers
  class MonitoringManager < BaseManager
    def self.ems_type
      "monitoring".freeze
    end

    def self.description
      "Monitoring Manager".freeze
    end

    def name
      "#{parent_manager.try(:name)} Monitoring Manager"
    end
  end
end
