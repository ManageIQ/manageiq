# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/autorun'
require 'rspec/rails'
require 'rspec/fire'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}
# include the lib matchers
Dir[Rails.root.join("../lib/spec/support/custom_matchers/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false

  # config.before(:all) do
  #   EvmSpecHelper.log_ruby_object_usage
  # end
  #
  # config.after(:all) do
  #   EvmSpecHelper.log_ruby_object_usage
  # end

  # Preconfigure and auto-tag specs in the automation subdirectory a la rspec-rails
  config.include RSpec::Rails::AutomationExampleGroup, :type => :automation, :example_group => {
    :file_path => config.escaped_path(%w[spec automation])
  }
  config.include RSpec::Fire

  config.extend  MigrationSpecHelper::DSL
  config.include MigrationSpecHelper, :migrations => :up
  config.include MigrationSpecHelper, :migrations => :down

  config.include ActionWebServiceInvokeHelper, :apis => true
  config.include ApiSpecHelper,                :type => :request, :rest_api => true, :example_group => {
    :file_path => config.escaped_path(%w(spec requests api))
  }

  config.include ControllerSpecHelper, :type => :controller
  config.include ViewSpecHelper, :type => :view
  config.include UiConstants, :type => :controller
  config.include UiConstants, :type => :view

  config.include AutomationSpecHelper, :type => :automation
  config.include PresenterSpecHelper, :type => :presenter, :example_group => {
    :file_path => config.escaped_path(%w[spec presenters])
  }
  config.include RakeTaskExampleGroup, :type => :rake_task

  config.before(:each) do
    Bullet.start_request if defined?(Bullet)
  end

  config.after(:each) do
    if defined?(Bullet)
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end
    EvmSpecHelper.clear_caches
  end
end

# PATCH: Temporary monkey patch until a new version of webmock is released
#   (newer than 1.11.0).  The aws-sdk gem uses a feature of Net::HTTP that has
#   not yet been properly exposed.
#   See: https://github.com/aws/aws-sdk-ruby/issues/232
#        https://github.com/bblimke/webmock/blob/master/lib/webmock/http_lib_adapters/net_http.rb#L196
class StubSocket
  attr_accessor :read_timeout, :continue_timeout
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock

  c.allow_http_connections_when_no_cassette = false
  c.default_cassette_options = {
    :allow_unused_http_interactions => !ENV['CC_BUILD_ARTIFACTS']
  }

  #c.debug_logger = File.open(Rails.root.join("log", "vcr_debug.log"), "w")
  #c.debug_logger = File.open(File.join(ENV['CC_BUILD_ARTIFACTS'], "vcr_debug.log"), "w") if ENV['CC_BUILD_ARTIFACTS']
end

# TODO: Remove this once 1.9.3 has this fixed
# ruby 1.9.2+ (1.9.3-p194) doesn't propagate exit codes properly when exceptions occur in an at_exit.
# The vmdb project reported 'green' despite test failures raising exceptions which set non-zero exit codes.
# http://bugs.ruby-lang.org/issues/5218
if defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby"
  module Kernel
    alias :__at_exit :at_exit
    def at_exit(&block)
      __at_exit do
        exit_status = $!.status if $!.is_a?(SystemExit)
        block.call
        exit exit_status if exit_status
      end
    end
  end
end
