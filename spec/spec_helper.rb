# This file is copied to spec/ when you run 'rails generate rspec:install'
if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path('../config/environment', __dir__)
require 'rspec/rails'
require 'rspec/mocks'
require 'vcr'
require 'cgi'

# Fail tests that try to include stuff in `main`
require_relative 'support/test_contamination'
Spec::Support::TestContamination.setup

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
# include the manageiq-gems-pending matchers
Dir[ManageIQ::Gems::Pending.root.join("spec/support/custom_matchers/*.rb")].each { |f| require f }
# include the manageiq-password matchers
require "manageiq/password/rspec_matchers"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.mock_with :rspec do |c|
    c.allow_message_expectations_on_nil = false
    c.syntax = :expect
  end

  config.before do
    # TODO: The following locations YAML load the Ruport objects, see if we can avoid serializing them here.
    # rspec ./spec/models/miq_report_result_spec.rb:8 # MiqReportResult #_async_generate_result
    # rspec ./spec/models/miq_report_result_spec.rb:111 # MiqReportResult persisting generated report results should save the original report metadata and the generated table as a binary blob
    # rspec ./spec/models/miq_report/generator_spec.rb:275 # MiqReport::Generator sorting handles sort columns with nil values properly, when column is string
    # rspec ./spec/models/service_spec.rb:510 # Service Chargeback report generation #chargeback_report returns chargeback report
    YamlPermittedClasses.app_yaml_permitted_classes |= [Ruport::Data::Record, Ruport::Data::Table]
  end

  config.file_fixture_path = "#{Rails.root.join("spec/fixtures")}"
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false

  # From rspec-rails, infer what helpers to mix in, such as `get` and
  # `post` methods in spec/controllers, without specifying type
  config.infer_spec_type_from_file_location!

  unless ENV['CI']
    # File store for --only-failures option
    config.example_status_persistence_file_path = Rails.root.join("tmp/rspec_example_store.txt")
  end

  config.include Spec::Support::RakeTaskExampleGroup, :type => :rake_task

  # config.before(:all) do
  #   EvmSpecHelper.log_ruby_object_usage
  # end
  # config.after(:all) do
  #   EvmSpecHelper.log_ruby_object_usage
  # end

  # everything requires a region
  config.before(:suite) do
    MiqRegion.seed
  end

  config.after(:suite) do
    MiqRegion.delete_all
  end

  config.before do
    EmsRefresh.try(:debug_failures=, true)
  end

  config.around(:each) do |example|
    EvmSpecHelper.clear_caches { example.run }
  end

  if ENV["CI"] && ENV["TEST_SUITE"] == "vmdb"
    config.before(:suite) do
      require Rails.root.join("spec/coverage_helper.rb")
    end
  end

  if config.backtrace_exclusion_patterns.delete(%r{/lib\d*/ruby/})
    config.backtrace_exclusion_patterns << %r{/lib\d*/ruby/[0-9]}
  end

  config.backtrace_exclusion_patterns << %r{/spec/spec_helper}
  config.backtrace_exclusion_patterns << %r{/spec/support/evm_spec_helper}
end

VCR.configure do |c|
  c.cassette_library_dir = Rails.root.join('spec/vcr_cassettes')
  c.hook_into :webmock

  c.allow_http_connections_when_no_cassette = false
  c.default_cassette_options = {
    :allow_unused_http_interactions => false
  }

  # c.debug_logger = File.open(Rails.root.join("log", "vcr_debug.log"), "w")
end
