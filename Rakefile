#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require 'bigdecimal'
puts "Mem: #{((1024 * BigDecimal.new(`ps -o rss= -p #{Process.pid}`))/BigDecimal.new(1_048_576)).to_f}MiB"

include Rake::DSL

require File.expand_path('../lib/tasks/evm_rake_helper', __FILE__)
if ARGV.any? {|arg| arg.start_with?("evm:") && arg.scan(/:/).count == 1 }
  $:.push(File.expand_path("../lib", __FILE__))

  load File.expand_path("../lib/tasks/evm.rake", __FILE__)
else
  require File.expand_path('../config/application', __FILE__)

  Vmdb::Application.load_tasks

  # Clear noisy and unusable tasks added by rspec-rails
  if defined?(RSpec)
    Rake::Task.tasks.select { |t| t.name =~ /^spec(:)?/ }.each(&:clear)
  end
end
