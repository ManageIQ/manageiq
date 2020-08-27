require_relative "../plugin/plugin_generator"

module ManageIQ
  class ProviderGenerator < PluginGenerator
    source_root File.expand_path('templates', __dir__)

    def self.manager_types
      @manager_types ||= {
        "automation"    => "AutomationManager",
        "cloud"         => "CloudManager",
        "configuration" => "ConfigurationManager",
        "container"     => "ContainerManager",
        "infra"         => "InfraManager",
        "monitoring"    => "MonitoringManager",
        "network"       => "NetworkManager",
        "physical"      => "PhysicalInfraManager",
        "provisioning"  => "ProvisioningManager",
        "storage"       => "StorageManager"
      }
    end

    class_option :vcr, :type => :boolean, :default => false,
                 :desc => "Enable VCR cassettes (Default: --no-vcr)"

    class_option :scaffolding, :type => :boolean, :default => true,
                 :desc => "Generate default class scaffolding (Default: --scaffolding)"

    class_option :manager_type, :type => :string,
                 :desc => "What type of manager to create, required if building scaffolding (Options: #{manager_types.keys.join(", ")})"

    def create_provider_files
      empty_directory "spec/models/#{plugin_path}"

      gsub_file "lib/tasks_private/spec.rake", /'app:test:spec_deps'/ do |match|
        "[#{match}, 'app:test:providers_common']"
      end

      create_scaffolding if options[:scaffolding]
      create_vcr         if options[:vcr]
    end

    private

    alias provider_name file_name

    def plugin_human_name
      @plugin_human_name ||= "#{file_name.titleize} Provider"
    end

    def plugin_description
      @plugin_description ||= "#{Vmdb::Appliance.PRODUCT_NAME} plugin for the #{file_name.titleize} provider."
    end

    def validate_manager_type!
      return unless manager_type.nil?

      raise "Invalid manager_type: #{options[:manager_type]}\nMust be one of #{self.class.manager_types.keys.join(", ")}"
    end

    def manager_type
      @manager_type ||= self.class.manager_types[options[:manager_type]]
    end

    def manager_path
      manager_type.underscore
    end

    def create_scaffolding
      validate_manager_type!
      template "app/models/%plugin_path%/%manager_path%/event_catcher/runner.rb"
      template "app/models/%plugin_path%/%manager_path%/event_catcher/stream.rb"
      template "app/models/%plugin_path%/%manager_path%/metrics_collector_worker/runner.rb"
      template "app/models/%plugin_path%/%manager_path%/refresh_worker/runner.rb"
      template "app/models/%plugin_path%/%manager_path%/event_catcher.rb"
      template "app/models/%plugin_path%/%manager_path%/metrics_capture.rb"
      template "app/models/%plugin_path%/%manager_path%/metrics_collector_worker.rb"
      template "app/models/%plugin_path%/%manager_path%/refresh_worker.rb"
      template "app/models/%plugin_path%/%manager_path%/refresher.rb"
      template "app/models/%plugin_path%/%manager_path%/vm.rb"
      template "app/models/%plugin_path%/inventory.rb"
      template "app/models/%plugin_path%/inventory/collector.rb"
      template "app/models/%plugin_path%/inventory/parser.rb"
      template "app/models/%plugin_path%/inventory/persister.rb"
      template "app/models/%plugin_path%/inventory/collector/%manager_path%.rb"
      template "app/models/%plugin_path%/inventory/parser/%manager_path%.rb"
      template "app/models/%plugin_path%/inventory/persister/definitions/cloud_collections.rb"
      template "app/models/%plugin_path%/inventory/persister/%manager_path%.rb"
      template "app/models/%plugin_path%/inventory/persister.rb"
      template "app/models/%plugin_path%/%manager_path%.rb"
    end

    def create_vcr
      inject_into_file '.yamllint', "  /spec/vcr_cassettes/**\n", :after => "  /spec/manageiq/**\n"

      append_file 'spec/spec_helper.rb', <<~VCR

        VCR.configure do |config|
          config.ignore_hosts 'codeclimate.com' if ENV['CI']
          config.cassette_library_dir = File.join(#{class_name}::Engine.root, 'spec/vcr_cassettes')
        end
      VCR
    end
  end
end
