module ManageIQ::Providers::Redhat::InfraManager::EventParser
  def self.parse_new_target(full_data, message, ems, event_type)
    parser = ManageIQ::Providers::Redhat::InfraManager::EventParsing::Builder.new(ems).build
    parser.parse_new_target(full_data, message, ems, event_type)
  end
end
