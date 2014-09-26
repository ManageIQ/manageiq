require_relative "./evm_test_helper"

if defined?(RSpec)
namespace :test do
  task :setup_migrations => :setup_db

  desc "Run all migration specs"
  task :migrations => %w(
    test:initialize
    test:migrations:down
    test:migrations:complete_down
    test:migrations:up
    test:migrations:complete_up
  )

  namespace :migrations do
    desc "Run the up migration specs only"
    RSpec::Core::RakeTask.new(:up => :initialize) do |t|
      EvmTestHelper.init_rspec_task(t, ["--tag", "migrations:up"])
      t.pattern = EvmTestHelper::MIGRATION_SPECS
    end

    desc "Run the down migration specs only"
    RSpec::Core::RakeTask.new(:down => :initialize) do |t|
      EvmTestHelper.init_rspec_task(t, ["--tag", "migrations:down"])
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

    task :complete_up => :initialize do
      puts "** Migrating all the way up"
      EvmTestHelper.run_rake_via_shell("db:migrate", "VERBOSE" => ENV["VERBOSE"] || "false")
    end

    task :complete_down => :initialize do
      puts "** Migrating all the way down"
      EvmTestHelper.run_rake_via_shell("db:migrate", "VERSION" => "0", "VERBOSE" => ENV["VERBOSE"] || "false")
    end
  end
end
end # ifdef
