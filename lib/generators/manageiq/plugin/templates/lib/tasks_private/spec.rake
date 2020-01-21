namespace :spec do
  desc "Setup environment specs"
  task :setup => ["app:test:vmdb:setup"]
end

desc "Run all specs"
RSpec::Core::RakeTask.new(:spec => 'app:test:spec_deps') do |t|
  EvmTestHelper.init_rspec_task(t)
end
