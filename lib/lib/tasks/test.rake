require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = FileList['test/ts_*.rb'] - ['test/ts_mdfs.rb']
end

namespace :test do
  Rake::TestTask.new(:extract)  { |t| t.test_files = ['test/ts_extract.rb'] }
  Rake::TestTask.new(:miq_disk) { |t| t.test_files = ['test/ts_mdfs.rb'] }

  namespace :lib do
    task :setup # NOOP - Stub for consistent CI testing
  end

  desc "Run all lib specs and tests except MiqDisk tests"
  task :lib => [:spec, :test, "spec:foreman"]
end

task :default => 'test:lib'
