require_relative "./evm_test_helper"

if defined?(RSpec)
namespace :test do
  task :setup_replication => :initialize do
    EvmTestSetupReplication.new.execute
  end

  desc "Run all replication specs"
  RSpec::Core::RakeTask.new(:replication => :initialize) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = EvmTestHelper::REPLICATION_SPECS
  end
end
end # ifdef

class EvmTestSetupReplication
  def initialize
    @db_yaml_file      = Rails.root.join("config", "database.yml")
    @db_yaml_file_orig = Rails.root.join("config", "database.evm_test_setup_replication.yml")
    @region_file       = Rails.root.join("REGION")
    @region_file_orig  = Rails.root.join("REGION.evm_test_setup_replication")
  end

  def execute
    prepare_slave_database
    prepare_master_database
  end

  private

  def prepare_slave_database
    puts "** Preparing slave database"
    db_reset
  end

  def prepare_master_database
    puts "** Preparing master database"
    backup_system_files

    begin
      File.open(@region_file, "w") { |f| f.puts(99) }
      config = YAML.load(File.read(@db_yaml_file))
      config["test"]["database"] += "_master"
      File.open(@db_yaml_file, "w") { |f| f.puts(config.to_yaml) }

      db_reset
    ensure
      restore_system_files
    end
  end

  def db_reset
    env = {
      "RAILS_ENV" => ENV["RAILS_ENV"] || "test",
      "VERBOSE"   => ENV["VERBOSE"]   || "false",
    }
    EvmTestHelper.run_rake_via_shell("evm:db:reset", env)
  end

  def backup_system_files
    FileUtils.cp(@db_yaml_file, @db_yaml_file_orig)
    FileUtils.cp(@region_file,  @region_file_orig) if File.exists?(@region_file)
  end

  def restore_system_files
    FileUtils.mv(@db_yaml_file_orig, @db_yaml_file)
    if File.exists?(@region_file_orig)
      FileUtils.mv(@region_file_orig, @region_file)
    else
      FileUtils.rm(@region_file)
    end
  end
end
