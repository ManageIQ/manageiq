module ManageIQ::Providers
  module AnsibleTower
    class AutomationManager::RefreshParser
      include Vmdb::Logging

      def self.automation_manager_inv_to_hashes(ems, options = nil)
        new(ems, options).automation_manager_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems        = ems
        @connection = ems.connect
        @options    = options || {}
        @data       = {}
        @data_index = {}
      end

      def automation_manager_inv_to_hashes
        log_header = "Collecting data for AutomationManager : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_inventories
        get_hosts
        get_job_templates
        _log.info("#{log_header}...Complete")

        @data
      end

      private

      def get_hosts
        hosts = @connection.api.hosts.all
        process_collection(hosts, :configured_systems) { |host| parse_host(host) }
      end

      def get_inventories
        inventories = @connection.api.inventories.all
        process_collection(inventories, :ems_folders) { |inventory| parse_inventory(inventory) }
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

      def parse_host(host)
        inventory_root_group = @data_index.fetch_path(:ems_folders, host.inventory_id)
        name = uid = host.name

        new_result = {
          :type                 => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem",
          :manager_ref          => host.id.to_s,
          :hostname             => name,
          :inventory_root_group => inventory_root_group,
          :virtual_instance_ref => host.instance_id,
        }

        cross_link_host(new_result)

        return uid, new_result
      end

      def cross_link_host(new_result)
        vm = Vm.where(:uid_ems => new_result[:virtual_instance_ref]).first
        new_result[:counterpart] = vm
      end

      def parse_inventory(inventory)
        uid = inventory.id

        new_result = {
          :type    => "ManageIQ::Providers::AutomationManager::InventoryRootGroup",
          :ems_ref => inventory.id.to_s,
          :name    => inventory.name,
        }

        return uid, new_result
      end

      def parse_job_template(job_template)
        inventory_root_group = @data_index.fetch_path(:ems_folders, job_template.inventory_id)
        uid = job_template.name

        new_result = {
          :description          => job_template.description,
          :inventory_root_group => inventory_root_group,
          :manager_ref          => job_template.id.to_s,
          :name                 => job_template.name,
          :survey_spec          => job_template.survey_spec_hash,
          :type                 => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript",
          :variables            => job_template.extra_vars_hash
        }

        return uid, new_result
      end
    end
  end
end
