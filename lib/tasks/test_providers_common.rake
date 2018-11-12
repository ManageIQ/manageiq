require_relative './evm_test_helper'

if defined?(RSpec)
namespace :test do
  desc "Run all specs tagged 'providers_common'"
  RSpec::Core::RakeTask.new(:providers_common => ["test:initialize", "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t, ['--tag', 'providers_common'])

    if defined?(ENGINE_ROOT)
      t.rspec_opts += ["--exclude-pattern", "manageiq/spec/tools/**/*_spec.rb"]
      t.pattern = "manageiq/spec/**/*_spec.rb"
    end
  end
end
end
