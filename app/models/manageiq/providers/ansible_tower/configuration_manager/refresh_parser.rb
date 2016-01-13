module ManageIQ::Providers
  module AnsibleTower
    class ConfigurationManager::RefreshParser
      include Vmdb::Logging

      def self.configuration_inv_to_hashes(inv)
        new.configuration_inv_to_hashes(inv)
      end

      def configuration_inv_to_hashes(inv)
        {:configured_systems => configured_system_inv_to_hashes(inv[:hosts])}
      end

      def configured_system_inv_to_hashes(recs)
        recs.collect do |cs|
          {
            :type        => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem",
            :manager_ref => cs.id.to_s,
            :hostname    => cs.name,
          }
        end
      end
    end
  end
end
