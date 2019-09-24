require_relative "../plugin/plugin_generator"

module ManageIQ
  class ProviderGenerator < PluginGenerator
    source_root File.expand_path('templates', __dir__)

    class_option :vcr, :type => :boolean, :default => false,
                 :desc => "Enable VCR cassettes (Default: --no-vcr)"

    class_option :dummy, :type => :boolean, :default => false,
                 :desc => "Generate dummy implementations (Default: --no-dummy)"

    def create_provider_files
      empty_directory "spec/models/#{plugin_path}"

      gsub_file "lib/tasks_private/spec.rake", /'app:test:spec_deps'/ do |match|
        "[#{match}, 'app:test:providers_common']"
      end

      create_dummy if options[:dummy]
      create_vcr   if options[:vcr]
    end

    private

    alias provider_name file_name

    def create_dummy
      template "app/models/%plugin_path%/cloud_manager/event_catcher/runner.rb"
      template "app/models/%plugin_path%/cloud_manager/event_catcher/stream.rb"
      template "app/models/%plugin_path%/cloud_manager/metrics_collector_worker/runner.rb"
      template "app/models/%plugin_path%/cloud_manager/refresh_worker/runner.rb"
      template "app/models/%plugin_path%/cloud_manager/event_catcher.rb"
      template "app/models/%plugin_path%/cloud_manager/metrics_capture.rb"
      template "app/models/%plugin_path%/cloud_manager/metrics_collector_worker.rb"
      template "app/models/%plugin_path%/cloud_manager/refresh_worker.rb"
      template "app/models/%plugin_path%/cloud_manager/refresher.rb"
      template "app/models/%plugin_path%/cloud_manager/vm.rb"
      template "app/models/%plugin_path%/inventory/collector/cloud_manager.rb"
      template "app/models/%plugin_path%/inventory/parser/cloud_manager.rb"
      template "app/models/%plugin_path%/inventory/persister/definitions/cloud_collections.rb"
      template "app/models/%plugin_path%/inventory/persister/cloud_manager.rb"
      template "app/models/%plugin_path%/inventory/persister.rb"
      template "app/models/%plugin_path%/cloud_manager.rb"

      inject_into_file Rails.root.join('lib/workers/miq_worker_types.rb'), <<~RB.indent(2), :after => "MIQ_WORKER_TYPES = {\n"
        "#{class_name}::CloudManager::EventCatcher"                        => %i(manageiq_default),
        "#{class_name}::CloudManager::MetricsCollectorWorker"              => %i(manageiq_default),
        "#{class_name}::CloudManager::RefreshWorker"                       => %i(manageiq_default),
      RB
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
