require_relative "./evm_test_helper"

if defined?(RSpec) && defined?(RSpec::Core::RakeTask)
namespace :test do
  namespace :vmdb do
    desc "Setup environment for vmdb specs"
    task :setup => [:verify_no_db_access_loading_rails_environment, :setup_db]
  end

  desc "Run all specs except migrations, replication, and automation"
  RSpec::Core::RakeTask.new(:vmdb => :initialize) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = EvmTestHelper::VMDB_SPECS
  end
end
end # ifdef
