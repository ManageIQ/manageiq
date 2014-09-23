begin
  require 'rspec/core/rake_task'
rescue LoadError
  module RSpec
    module Core
      class RakeTask
        def initialize(name)
          task name do
            # ... otherwise, do this:
            raise <<-MSG

#{"*" * 80}
*  You are trying to run an rspec rake task defined in
*  #{__FILE__},
*  but rspec can not be found in vendor/gems, vendor/plugins or system gems.
#{"*" * 80}
            MSG
          end
        end
      end
    end
  end
end

namespace :spec do
  namespace :evm do
    def initialize_task(t, rspec_opts = [])
      rspec_opts_file = ".rspec#{"_ci" if ENV['CI']}"
      t.rspec_opts = ['--options', "\"#{Rails.root.join(rspec_opts_file)}\""] + rspec_opts
      t.verbose = false
    end

    desc "Run the backend code examples"
    RSpec::Core::RakeTask.new(:backend) do |t|
      initialize_task(t)
      t.pattern = Rails.env == "metric_fu" ? EvmTestHelper::METRICS_SPECS : EvmTestHelper::BACKEND_SPECS
    end

    desc "Run the replication code examples"
    RSpec::Core::RakeTask.new(:replication) do |t|
      initialize_task(t)
      t.pattern = EvmTestHelper::REPLICATION_SPECS
    end

    desc "Run the automation code examples"
    RSpec::Core::RakeTask.new(:automation) do |t|
      initialize_task(t)
      t.pattern = EvmTestHelper::AUTOMATION_SPECS
    end

    namespace :migrations do
      desc "Run the up migration code examples"
      RSpec::Core::RakeTask.new(:up) do |t|
        initialize_task(t, ["--tag", "migrations:up"])
        t.pattern = EvmTestHelper::MIGRATION_SPECS
      end

      desc "Run the down migration code examples"
      RSpec::Core::RakeTask.new(:down) do |t|
        initialize_task(t, ["--tag", "migrations:down"])
        # NOTE: Since the upgrade to RSpec 2.12, pattern is automatically sorted
        #       under the covers, so the .reverse here is not honored.  There is
        #       currently no way to force the ordering, so the migrations will
        #       just have to run in a sawtooth order.
        #
        #       See: https://github.com/rspec/rspec-core/issues/881
        #            https://github.com/rspec/rspec-core/pull/660
        #            https://github.com/rspec/rspec-core/blob/v2.12.0/lib/rspec/core/rake_task.rb#L164
        t.pattern = EvmTestHelper::MIGRATION_SPECS.reverse
      end
    end
  end
end
