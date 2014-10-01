require_relative './evm_test_helper'

if defined?(RSpec)
namespace :test do
  task :initialize do
    ENV['RAILS_ENV'] ||= "test"
    Rails.env = ENV['RAILS_ENV'] if defined?(Rails)
    ENV['VERBOSE']   ||= "false"

    EvmTestHelper.cc_start_top if ENV['CC_BUILD_ARTIFACTS']
  end

  task :setup_db => :initialize do
    Rake::Task['evm:db:reset'].invoke
  end
end

task :default => 'test:vmdb'
end # ifdef
