namespace :test do
  task :setup_lib # NOOP - Stub for consistent CI testing

  desc "Run all lib specs and tests except MiqDisk tests"
  task :lib => [:spec, :test]
end

task :default => 'test:lib'
