module ManageIQ::Providers
  module AnsibleTower
    class ConfigurationManager::RefreshParser
      include Vmdb::Logging

      def self.configuration_manager_inv_to_hashes(ems, options = nil)
        new(ems, options).configuration_manager_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems        = ems
        @connection = ems.connect
        @options    = options || {}
        @data       = {}
        @data_index = {}
      end

      def configuration_manager_inv_to_hashes
        log_header = "Collecting data for ConfigurationManager : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_hosts
        get_job_templates
        _log.info("#{log_header}...Complete")

        @data
      end

      private

      def get_hosts
        hosts = @connection.api.hosts.all
        process_collection(hosts, :configured_systems) { |host| parse_hosts(host) }
      end

      def get_job_templates
        job_templates = @connection.api.job_templates.all
        process_collection(job_templates, :configuration_scripts) { |job_template| parse_job_template(job_template) }
      end

      def process_collection(collection, key)
        @data[key] ||= []

        collection.each do |item|
          uid, new_result = yield(item)
          next if uid.nil?

          @data[key] << new_result
          @data_index.store_path(key, uid, new_result)
        end
      end

      def parse_hosts(host)
        name = uid = host.name

        new_result = {
          :type        => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem",
          :manager_ref => host.id.to_s,
          :hostname    => name,
        }

        return uid, new_result
      end

      def parse_job_template(job_template)
        uid = job_template.name

        new_result = {
          :manager_ref => job_template.id.to_s,
          :name        => job_template.name,
          :description => job_template.description,
          :variables   => job_template.extra_vars,
        }

        return uid, new_result
      end
    end
  end
end
