# This file is copied to spec/ when you run 'rails generate rspec:install'
if ENV["TRAVIS"] || ENV['CI']
  require 'coveralls'
  require 'simplecov'
  SimpleCov.start
  Coveralls.wear!('rails') { add_filter("/spec/") }
end

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
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

# To be extracted with embedded_ansible
require ManageIQ::Providers::AnsibleTower::Engine.root.join("spec/support/vcr_helper.rb").to_s
Dir[ManageIQ::Providers::AnsibleTower::Engine.root.join("spec/support/ansible_shared/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.mock_with :rspec do |c|
    c.allow_message_expectations_on_nil = false
    c.syntax = :expect
  end

  config.fixture_path = "#{::Rails.root}/spec/fixtures"
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

  config.before do
    EmsRefresh.try(:debug_failures=, true)
  end

  config.around(:each) do |example|
    EvmSpecHelper.clear_caches { example.run }
  end

  if ENV["TRAVIS"] && ENV["TEST_SUITE"] == "vmdb"
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

  # Set your config/secrets.yml file
  secrets = Rails.application.secrets

  # Looks for provider subkeys you set in secrets.yml. Replace the values of
  # those keys (both escaped or unescaped) with some placeholder text.
  secrets.keys.each do |provider|
    next if [:secret_key_base, :secret_token].include?(provider) # Defaults
    cred_hash = secrets.public_send(provider)
    cred_hash.each do |key, value|
      c.filter_sensitive_data("#{provider.upcase}_#{key.upcase}") { CGI.escape(value) }
      c.filter_sensitive_data("#{provider.upcase}_#{key.upcase}") { value }
    end
  end

  # c.debug_logger = File.open(Rails.root.join("log", "vcr_debug.log"), "w")
end
