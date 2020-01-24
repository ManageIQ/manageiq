Vmdb::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  config.eager_load_paths = []

  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true
  config.eager_load = false

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Configure static asset server for tests with Cache-Control for performance
  config.public_file_server.enabled = true
  config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=3600' }

  # Avoid potential warnings and race conditions
  config.assets.configure do |env|
    env.cache = ActiveSupport::Cache.lookup_store(:memory_store)
  end

  config.assets.compile = true

  # Log error messages when you accidentally call methods on nil
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = false
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

  # Any exception that gets past our ApplicationController's rescue_from
  # should just be raised intact
  config.middleware.delete(::ActionDispatch::ShowExceptions)
  config.middleware.delete(::ActionDispatch::DebugExceptions)

  # Customize any additional options below...

  # Do not include all helpers for all views
  config.action_controller.include_all_helpers = false
  config.secret_key_base = SecureRandom.random_bytes(32)
end

require "minitest"
require "factory_bot"
require "timecop"
require "vcr"
require "webmock/rspec"
require "capybara"

module AssumeAssetPrecompiledInTest
  def asset_precompiled?(_logical_path)
    true
  end
end
Vmdb::Application.prepend(AssumeAssetPrecompiledInTest)
