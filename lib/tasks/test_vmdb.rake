require_relative "./evm_test_helper"

if defined?(RSpec) && defined?(RSpec::Core::RakeTask)
namespace :test do
  namespace :vmdb do
    task :setup => :setup_db
  end

  desc "Run all specs except migrations, replication, and automation"
  RSpec::Core::RakeTask.new(:vmdb => :initialize) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = Rails.env == "metric_fu" ? EvmTestHelper::METRICS_SPECS : EvmTestHelper::VMDB_SPECS
  end
end
end # ifdef
