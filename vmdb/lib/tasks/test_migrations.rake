require_relative "./evm_test_helper"

namespace :evm do
  namespace :test do
    namespace :complete_migrations do
      task :up do
        puts "** Migrating all the way up"
        EvmTestHelper.run_rake_via_shell("db:migrate", "VERBOSE" => ENV["VERBOSE"] || "false")
      end

      task :down do
        puts "** Migrating all the way down"
        EvmTestHelper.run_rake_via_shell("db:migrate", "VERSION" => "0", "VERBOSE" => ENV["VERBOSE"] || "false")
      end
    end
  end
end
