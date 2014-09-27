require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = FileList['test/ts_*.rb'] - ['test/ts_mdfs.rb']
end

namespace :test do
  Rake::TestTask.new(:miq_disk) do |t|
    t.test_files = ['test/ts_mdfs.rb']
  end

  task :setup_lib # NOOP - Stub for consistent CI testing

  desc "Run all lib specs and tests except MiqDisk tests"
  task :lib => [:spec, :test]
end

task :default => 'test:lib'
