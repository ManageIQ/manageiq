namespace :spec do
  desc "Setup environment specs"
  task :setup => ["app:test:vmdb:setup"]
end

desc "Run all specs"
RSpec::Core::RakeTask.new(:spec => ["app:test:initialize", "app:evm:compile_sti_loader", "app:test:providers_common"]) do |t|
  spec_dir = File.expand_path("../../spec", __dir__)
  EvmTestHelper.init_rspec_task(t, ['--require', File.join(spec_dir, 'spec_helper')])
end
