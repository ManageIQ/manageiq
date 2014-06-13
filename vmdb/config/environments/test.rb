Vmdb::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true

  # Configure static asset server for tests with Cache-Control for performance
  config.serve_static_assets = true
  config.static_cache_control = "public, max-age=3600"

  # Log error messages when you accidentally call methods on nil
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = true

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Raise exception on mass assignment protection for Active Record models
  # TODO: Fix our code to abide by Rails mass_assignment protection:
  # http://jonathanleighton.com/articles/2011/mass-assignment-security-shouldnt-happen-in-the-model/
  # config.active_record.mass_assignment_sanitizer = :strict

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr


  # Customize any additional options below...

  # Do not include all helpers for all views
  config.action_controller.include_all_helpers = false
end

require "shoulda-matchers"
require "factory_girl"
require "timecop"
require "vcr"
require "webmock/rspec"
require "capybara"

if ENV['CC_BUILD_ARTIFACTS']
  require "bullet"
  Bullet.enable = true

  # Use a log file in the CC_BUILD_ARTIFACTS directory so they're available automatically
  Bullet.bullet_logger = true
  logger = UniformNotifier::CustomizedLogger.instance_variable_get(:@logger)
  logger.close
  UniformNotifier::CustomizedLogger.instance_variable_set(:@logger, nil)

  bullet_log = File.expand_path(File.join(ENV['CC_BUILD_ARTIFACTS'], "bullet.log"))
  bullet_log_file = File.open(bullet_log, 'a+')
  bullet_log_file.sync
  UniformNotifier.customized_logger = bullet_log_file
end
