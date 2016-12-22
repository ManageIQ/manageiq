#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)
require File.expand_path('../lib/tasks/evm_rake_helper', __FILE__)

include Rake::DSL
Vmdb::Application.load_tasks

# Clear noisy and unusable tasks added by rspec-rails
if defined?(RSpec)
  Rake::Task.tasks.select { |t| t.name =~ /^spec(:)?/ }.each(&:clear)
end
