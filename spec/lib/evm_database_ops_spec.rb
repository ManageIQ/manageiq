require 'util/runcmd'
describe EvmDatabaseOps do
  context "#backup" do
    before(:each) do
      @connect_opts = {:username => 'blah', :password => 'blahblah', :uri => "smb://myserver.com/share"}
      @db_opts =      {:dbname => 'vmdb_production', :username => 'root'}
      allow(MiqSmbSession).to receive(:runcmd)
      allow_any_instance_of(MiqSmbSession).to receive(:settings_mount_point).and_return(Rails.root.join("tmp"))
      allow(MiqUtil).to receive(:runcmd)
      allow(PostgresAdmin).to receive(:runcmd_with_logging)
      allow(FileUtils).to receive(:mv).and_return(true)
      allow(EvmDatabaseOps).to receive(:backup_destination_free_space).and_return(200.megabytes)
      allow(EvmDatabaseOps).to receive(:database_size).and_return(100.megabytes)
    end

    it "locally" do
      local_backup = "/tmp/backup_1"
      @db_opts[:local_file] = local_backup
      expect(EvmDatabaseOps.backup(@db_opts, @connect_opts)).to eq(local_backup)
    end

    it "defaults" do
      local_backup = "/tmp/backup_1"
      @db_opts[:local_file] = local_backup
      expect(EvmDatabaseOps.backup(@db_opts, {})).to eq(local_backup)
    end

    it "without enough free space" do
      EvmSpecHelper.create_guid_miq_server_zone
      allow(EvmDatabaseOps).to receive(:backup_destination_free_space).and_return(100.megabytes)
      allow(EvmDatabaseOps).to receive(:database_size).and_return(200.megabytes)
      expect { EvmDatabaseOps.backup(@db_opts, @connect_opts) }.to raise_error(MiqException::MiqDatabaseBackupInsufficientSpace)
      expect(MiqQueue.where(:class_name => "MiqEvent", :method_name => "raise_evm_event").count).to eq(1)
    end

    it "remotely" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = "custom_backup"
      expect(EvmDatabaseOps.backup(@db_opts, @connect_opts)).to eq("smb://myserver.com/share/db_backup/custom_backup")
    end

    it "remotely without a remote file name" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = nil
      expect(EvmDatabaseOps.backup(@db_opts, @connect_opts)).to match(/smb:\/\/myserver.com\/share\/db_backup\/miq_backup_.*/)
    end
  end

  context "#restore" do
    before(:each) do
      @connect_opts = {:username => 'blah', :password => 'blahblah'}
      @db_opts =      {:dbname => 'vmdb_production', :username => 'root'}
      allow(MiqSmbSession).to receive(:runcmd)
      allow(MiqSmbSession).to receive(:raw_disconnect)
      allow_any_instance_of(MiqSmbSession).to receive(:settings_mount_point).and_return(Rails.root.join("tmp"))
      allow(PostgresAdmin).to receive(:runcmd_with_logging)
      allow(PostgresAdmin).to receive(:pg_dump_file?).and_return(true)
    end

    it "from local backup" do
      local_backup = "/tmp/backup_1"
      @db_opts[:local_file] = local_backup
      expect(EvmDatabaseOps.restore(@db_opts, @connect_opts)).to eq(local_backup)
    end

    it "from smb backup" do
      @db_opts[:local_file] = nil
      remote_backup = "smb://myserver.com/share/pg_backup1.backup"
      @connect_opts[:uri] = remote_backup
      expect(EvmDatabaseOps.restore(@db_opts, @connect_opts)).to eq(remote_backup)
    end
  end
end
