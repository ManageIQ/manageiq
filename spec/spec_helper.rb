# This file is copied to spec/ when you run 'rails generate rspec:install'

if ENV["TRAVIS"]
  require 'coveralls'
  Coveralls.wear!('rails') { add_filter("/spec/") }
end

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'application_helper'

require 'rails-controller-testing'
require 'rspec/rails'
require 'vcr'
require 'cgi'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
# include the gems/pending matchers
Dir[File.join(GEMS_PENDING_ROOT, "spec/support/custom_matchers/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.mock_with :rspec do |c|
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
    config.example_status_persistence_file_path = "./spec/examples.txt"
  end

  config.include VMDBConfigurationHelper

  config.define_derived_metadata(:file_path => /spec\/lib\/miq_automation_engine\/models/) do |metadata|
    metadata[:type] ||= :model
  end

  config.include AuthHelper,     :type => :view
  config.include ViewSpecHelper, :type => :view
  config.include UiConstants,    :type => :view

  config.include ControllerSpecHelper, :type => :controller
  config.include UiConstants,          :type => :controller
  config.include AuthHelper,           :type => :controller

  config.include AutomationSpecHelper,   :type => :automation
  config.include AutomationExampleGroup, :type => :automation
  config.define_derived_metadata(:file_path => /spec\/automation/) do |metadata|
    metadata[:type] ||= :automation
  end

  config.extend  MigrationSpecHelper::DSL
  config.include MigrationSpecHelper, :migrations => :up
  config.include MigrationSpecHelper, :migrations => :down

  config.include ApiSpecHelper,     :type => :request, :rest_api => true
  config.include AuthRequestHelper, :type => :request
  config.define_derived_metadata(:file_path => /spec\/requests\/api/) do |metadata|
    metadata[:type] ||= :request
  end

  config.include AuthHelper,  :type => :helper

  config.include PresenterSpecHelper, :type => :presenter
  config.define_derived_metadata(:file_path => /spec\/presenters/) do |metadata|
    metadata[:type] ||= :presenter
  end

  config.include RakeTaskExampleGroup, :type => :rake_task
  config.include ButtonSpecHelper, :type => :button
  config.define_derived_metadata(:file_path => /spec\/helpers\/application_helper\/buttons/) do |metadata|
    metadata[:type] = :button
  end

  # config.before(:all) do
  #   EvmSpecHelper.log_ruby_object_usage
  # end
  # config.after(:all) do
  #   EvmSpecHelper.log_ruby_object_usage
  # end

  config.before(:each) do |example|
    EmsRefresh.debug_failures = true if example.metadata[:migrations].blank?
    ApplicationController.handle_exceptions = false if %w(controller requests).include?(example.metadata[:type])
  end

  config.after(:each) do
    EvmSpecHelper.clear_caches
  end

  if ENV["TRAVIS"] && ENV["TEST_SUITE"] == "vmdb"
    config.after(:suite) do
      require Rails.root.join("spec/coverage_helper.rb")
    end
  end

  if config.backtrace_exclusion_patterns.delete(%r{/lib\d*/ruby/}) ||
     config.backtrace_exclusion_patterns.delete(%r{/gems/})
    config.backtrace_exclusion_patterns << %r{/lib\d*/ruby/[0-9]}
    config.backtrace_exclusion_patterns << %r{/gems/[0-9][^/]+/gems/}
  end
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
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
