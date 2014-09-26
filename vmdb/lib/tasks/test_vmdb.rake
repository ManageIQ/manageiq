require_relative "./evm_test_helper"

if defined?(RSpec)
namespace :test do
  task :setup_vmdb => :setup_db

  desc "Run all specs except migrations, replication, automation, and requests"
  RSpec::Core::RakeTask.new(:vmdb => :initialize) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = Rails.env == "metric_fu" ? EvmTestHelper::METRICS_SPECS : EvmTestHelper::VMDB_SPECS
  end
end
end # ifdef
