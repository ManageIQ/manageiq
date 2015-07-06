require "spec_helper"

describe EvmDatabaseOps do
  context "#backup" do
    before(:each) do
      @connect_opts = {:username => 'blah', :password => 'blahblah', :uri => "smb://myserver.com/share"}
      @db_opts =      {:dbname => 'vmdb_production', :username => 'root'}
      MiqSmbSession.stub(:runcmd)
      MiqSmbSession.stub(:base_mount_point).and_return(Rails.root.join("/tmp"))
      MiqUtil.stub(:runcmd)
      MiqPostgresAdmin.stub(:runcmd_with_logging)
      EvmDatabaseOps.stub(:backup_destination_free_space).and_return(200.megabytes)
      EvmDatabaseOps.stub(:database_size).and_return(100.megabytes)
    end

    it "locally" do
      local_backup = "/tmp/backup_1"
      @db_opts[:local_file] = local_backup
      EvmDatabaseOps.backup(@db_opts, @connect_opts).should == local_backup
    end

    it "defaults" do
      local_backup = "/tmp/backup_1"
      @db_opts[:local_file] = local_backup
      EvmDatabaseOps.backup(@db_opts, {}).should == local_backup
    end

    it "without enough free space" do
      EvmSpecHelper.create_guid_miq_server_zone
      EvmDatabaseOps.stub(:backup_destination_free_space).and_return(100.megabytes)
      EvmDatabaseOps.stub(:database_size).and_return(200.megabytes)
      lambda { EvmDatabaseOps.backup(@db_opts, @connect_opts)}.should raise_error(MiqException::MiqDatabaseBackupInsufficientSpace)
      msg = MiqQueue.first
      msg.class_name.should == "MiqEvent"
      msg.method_name.should == "raise_evm_event"
    end

    it "remotely" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = "custom_backup"
      EvmDatabaseOps.backup(@db_opts, @connect_opts).should == "smb://myserver.com/share/db_backup/custom_backup"
    end

    it "remotely without a remote file name" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = nil
      EvmDatabaseOps.backup(@db_opts, @connect_opts).should =~ /smb:\/\/myserver.com\/share\/db_backup\/miq_backup_.*/
    end
  end

  context "#restore" do
    before(:each) do
      @connect_opts = {:username => 'blah', :password => 'blahblah'}
      @db_opts =      {:dbname => 'vmdb_production', :username => 'root'}
      MiqSmbSession.stub(:runcmd)
      MiqSmbSession.stub(:raw_disconnect)
      MiqSmbSession.stub(:base_mount_point).and_return(Rails.root.join("/tmp"))
      MiqPostgresAdmin.stub(:runcmd_with_logging)
    end

    it "from local backup" do
      local_backup = "/tmp/backup_1"
      @db_opts[:local_file] = local_backup
      EvmDatabaseOps.restore(@db_opts, @connect_opts).should == local_backup
    end

    it "from smb backup" do
      @db_opts[:local_file] = nil
      remote_backup = "smb://myserver.com/share/pg_backup1.backup"
      @connect_opts[:uri] = remote_backup
      EvmDatabaseOps.restore(@db_opts, @connect_opts).should == remote_backup
    end
  end
end
