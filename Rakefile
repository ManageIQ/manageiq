#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)
require File.expand_path('../lib/tasks/evm_rake_helper', __FILE__)

include Rake::DSL
Vmdb::Application.load_tasks

begin
  require 'jasmine'
  load 'jasmine/tasks/jasmine.rake'

  # hack around Travis resolving localhost to IPv6 and failing
  module Jasmine
    class << self
      alias old_server_is_listening_on server_is_listening_on

      def server_is_listening_on(_hostname, port)
        old_server_is_listening_on('127.0.0.1', port)
      end
    end

    class Configuration
      alias old_initialize initialize

      def initialize
        @host = 'http://127.0.0.1'
        old_initialize
      end
    end
  end

rescue LoadError
  # Do nothing because we don't need jasmine in every environment
end

# Clear noisy and unusable tasks added by rspec-rails
if defined?(RSpec)
  Rake::Task.tasks.select { |t| t.name =~ /^spec(:)?/ }.each(&:clear)
end
