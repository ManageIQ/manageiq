require_relative "./evm_test_helper"

if defined?(RSpec) && defined?(RSpec::Core::RakeTask)
namespace :test do
  namespace :replication do
    desc "Setup environment for replication specs"
    task :setup => :initialize do
      EvmTestSetupReplication.new.write_released_migrations
    end
  end

  desc "Run all replication specs"
  RSpec::Core::RakeTask.new(:replication => :initialize) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = EvmTestHelper::REPLICATION_UTIL_SPECS
  end
end
end # ifdef

class EvmTestSetupReplication
  TEST_BRANCH = "evm_test_setup_replication_branch".freeze

  def write_released_migrations
    file_contents = released_migrations.sort.join("\n")
    File.write(Rails.root.join("spec/replication/util/data/euwe_migrations"), file_contents)
  end

  private

  def released_migrations
    unless system(fetch_command)
      return []
    end
    files = `git ls-tree -r --name-only #{TEST_BRANCH} db/migrate/`
    return [] unless $CHILD_STATUS.success?

    migrations = files.split.map do |path|
      filename = path.split("/")[-1]
      filename.split('_')[0]
    end

    # eliminate any non-timestamp entries
    migrations.keep_if { |timestamp| timestamp =~ /\d+/ }
  ensure
    `git branch -D #{TEST_BRANCH}`
  end

  def fetch_command
    "git fetch #{'--depth=1 ' if ENV['CI']}http://github.com/ManageIQ/manageiq.git refs/heads/euwe:#{TEST_BRANCH}"
  end
end
