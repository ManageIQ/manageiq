require "rails/generators/rails/app/app_generator"
class ProviderGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  alias provider_name file_name

  def initialize(*args)
    super
    self.destination_root = File.expand_path(provider_name, File.expand_path('providers', destination_root))
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
    template "config/initializers/gettext.rb"
    template "lib/manageiq/providers/%provider_name%.rb"
    template "lib/manageiq/providers/%provider_name%/engine.rb"
    template "lib/manageiq/providers/%provider_name%/version.rb"
    template "lib/tasks/spec.rake"
    empty_directory "spec/factories"
    empty_directory "spec/models/manageiq/providers/#{provider_name}"
    template "spec/spec_helper.rb"
    template "tools/ci/before_install.sh"
  end

  def create_manageiq_gem
    data = <<EOT
unless dependencies.detect { |d| d.name == "manageiq-providers-#{provider_name}" }
  gem "manageiq-providers-#{provider_name}", :path => File.expand_path("providers/#{provider_name}", __dir__)
end
EOT
    inject_into_file '../../Gemfile', data, :after => "# when using this Gemfile inside a providers Gemfile, the dependency for the provider is already declared\n"
  end

  private

  def empty_directory_with_keep_file(destination, config = {})
    empty_directory(destination, config)
    keep_file(destination)
  end

  def keep_file(destination)
    create_file("#{destination}/.keep")
  end
end
