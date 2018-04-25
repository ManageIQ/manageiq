require "rails/generators/rails/app/app_generator"
class ProviderGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  remove_class_option :skip_namespace

  class_option :path, :type => :string, :default => 'plugins',
               :desc => "Create provider at given path"

  class_option :vcr, :type => :boolean, :default => false,
               :desc => "Enable VCR cassettes (default off)"

  class_option :dummy, :type => :boolean, :default => false,
               :desc => "Generate dummy implementations (default off)"

  alias provider_name file_name

  def initialize(*args)
    super
    provider_path = File.expand_path(options[:path], destination_root)
    self.destination_root = File.expand_path("manageiq-providers-#{provider_name}", provider_path)
    empty_directory "."
    FileUtils.cd(destination_root)
  end

  def create_files
    template ".codeclimate.yml"
    template ".gitignore"
    template ".rspec"
    template ".rspec_ci"
    template ".rubocop.yml"
    template ".rubocop_cc.yml"
    template ".rubocop_local.yml"
    template ".travis.yml"
    template ".yamllint"
    template "Gemfile"
    template "LICENSE.txt"
    template "manageiq-providers-%provider_name%.gemspec"
    template "Rakefile"
    template "README.md"
    template "zanata.xml"
    empty_directory_with_keep_file "locale"
    empty_directory "app/models/manageiq/providers/#{provider_name}"
    template "bin/rails"
    template "bin/setup"
    template "bin/update"
    chmod "bin", 0755 & ~File.umask, :verbose => false
    template "config/initializers/gettext.rb"
    template "config/settings.yml"
    template "lib/manageiq-providers-%provider_name%.rb"
    template "lib/manageiq/providers/%provider_name%.rb"
    template "lib/manageiq/providers/%provider_name%/engine.rb"
    template "lib/manageiq/providers/%provider_name%/version.rb"
    template "lib/tasks/README.md"
    template "lib/tasks/%provider_name%.rake"
    template "lib/tasks_private/spec.rake"
    empty_directory "spec/factories"
    empty_directory "spec/models/manageiq/providers/#{provider_name}"
    empty_directory "spec/support"
    template "spec/spec_helper.rb"
    if options[:dummy]
      create_dummy
      add_worker_classnames
    end
  end

  def create_manageiq_gem
    data = <<~HEREDOC
      group :#{provider_name}, :manageiq_default do
        manageiq_plugin "manageiq-providers-#{provider_name}" # TODO: Sort alphabetically...
      end
    HEREDOC
    inject_into_file Rails.root.join('Gemfile'), "\n#{data}\n", :after => "### providers\n"
  end

  private

  def empty_directory_with_keep_file(destination, config = {})
    empty_directory(destination, config)
    keep_file(destination)
  end

  def keep_file(destination)
    create_file("#{destination}/.keep")
  end

  def create_dummy
    template "app/models/manageiq/providers/%provider_name%/cloud_manager.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/event_catcher.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/event_catcher/runner.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/event_catcher/stream.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/metrics_capture.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/metrics_collector_worker.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/metrics_collector_worker/runner.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/refresh_worker.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/refresh_worker/runner.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/refresher.rb"
    template "app/models/manageiq/providers/%provider_name%/cloud_manager/vm.rb"
    template "app/models/manageiq/providers/%provider_name%/inventory/collector/cloud_manager.rb"
    template "app/models/manageiq/providers/%provider_name%/inventory/parser/cloud_manager.rb"
    template "app/models/manageiq/providers/%provider_name%/inventory/persister/cloud_manager.rb"
  end

  def add_worker_classnames
    data = <<~HEREDOC
      "ManageIQ::Providers::#{class_name}::CloudManager::EventCatcher"                  => %i(manageiq_default),
      "ManageIQ::Providers::#{class_name}::CloudManager::MetricsCollectorWorker"        => %i(manageiq_default),
      "ManageIQ::Providers::#{class_name}::CloudManager::RefreshWorker"                 => %i(manageiq_default),
    HEREDOC
    inject_into_file Rails.root.join('lib/workers/miq_worker_types.rb'),
                     data,
                     :after => "MIQ_WORKER_TYPES = {\n"
  end
end
