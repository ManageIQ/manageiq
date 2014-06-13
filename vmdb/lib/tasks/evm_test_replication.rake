namespace :evm do
  namespace :test do
    task :setup_replication => 'evm:test:initialize' do
      EvmTestSetupReplication.new.execute
    end
  end
end

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
    run_rake_via_shell("evm:db:reset")
  end

  def prepare_master_database
    puts "** Preparing master database"
    backup_system_files

    begin
      File.open(@region_file, "w") { |f| f.puts(99) }
      config = YAML.load(File.read(@db_yaml_file))
      config["test"]["database"] = "vmdb_replication_master"
      File.open(@db_yaml_file, "w") { |f| f.puts(config.to_yaml) }

      run_rake_via_shell("evm:db:reset")
    ensure
      restore_system_files
    end
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

  def run_rake_via_shell(rake_command)
    pid, status = Process.wait2(Kernel.spawn("rake #{rake_command}", :chdir => Rails.root))
    exit(status.exitstatus) if status.exitstatus != 0
  end
end
