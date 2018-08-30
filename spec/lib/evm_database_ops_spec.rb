require 'util/runcmd'
describe EvmDatabaseOps do
  context "#backup" do
    let(:session) { double("MiqSmbSession", :disconnect => nil) }
    before do
      @connect_opts = {:username => 'blah', :password => 'blahblah', :uri => "smb://myserver.com/share"}
      @db_opts =      {:dbname => 'vmdb_production', :username => 'root'}
      allow(MiqGenericMountSession).to receive(:new_session).and_return(session)
      allow(session).to receive(:settings_mount_point).and_return(Rails.root.join("tmp").to_s)
      allow(session).to receive(:uri_to_local_path).and_return(Rails.root.join("tmp/share").to_s)
      allow(PostgresAdmin).to receive(:backup).and_return("/tmp/backup_1")
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
      expect(session).to receive(:add).and_return("smb://myserver.com/share/db_backup/custom_backup")
      expect(EvmDatabaseOps.backup(@db_opts, @connect_opts)).to eq("smb://myserver.com/share/db_backup/custom_backup")
    end

    it "remotely without a remote file name" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = nil
      expect(session).to receive(:add)
      expect(EvmDatabaseOps.backup(@db_opts, @connect_opts)).to match(/smb:\/\/myserver.com\/share\/db_backup\/miq_backup_.*/)
    end

    it "properly logs the result with no :dbname provided" do
      @db_opts.delete(:dbname)
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = nil
      allow(described_class).to receive(:backup_file_name).and_return("miq_backup")

      log_stub = instance_double("_log")
      expect(described_class).to receive(:_log).twice.and_return(log_stub)
      expect(log_stub).to        receive(:info).with(any_args)
      expect(log_stub).to        receive(:info).with("[vmdb_production] database has been backed up to file: [smb://myserver.com/share/db_backup/miq_backup]")
      expect(session).to receive(:add).and_return("smb://myserver.com/share/db_backup/miq_backup")

      EvmDatabaseOps.backup(@db_opts, @connect_opts)
    end
  end

  context "#dump" do
    before do
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
      local_dump = "/tmp/dump_1"
      @db_opts[:local_file] = local_dump
      expect(EvmDatabaseOps.dump(@db_opts, @connect_opts)).to eq(local_dump)
    end

    it "defaults" do
      local_dump = "/tmp/dump_1"
      @db_opts[:local_file] = local_dump
      expect(EvmDatabaseOps.dump(@db_opts, {})).to eq(local_dump)
    end

    it "without enough free space" do
      EvmSpecHelper.create_guid_miq_server_zone
      allow(EvmDatabaseOps).to receive(:backup_destination_free_space).and_return(100.megabytes)
      allow(EvmDatabaseOps).to receive(:database_size).and_return(200.megabytes)
      expect { EvmDatabaseOps.dump(@db_opts, @connect_opts) }.to raise_error(MiqException::MiqDatabaseBackupInsufficientSpace)
      expect(MiqQueue.where(:class_name => "MiqEvent", :method_name => "raise_evm_event").count).to eq(1)
    end

    it "remotely" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = "custom_pg_dump"
      expect(EvmDatabaseOps.dump(@db_opts, @connect_opts)).to eq("smb://myserver.com/share/db_dump/custom_pg_dump")
    end

    it "remotely without a remote file name" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = nil
      expect(EvmDatabaseOps.dump(@db_opts, @connect_opts)).to match(/smb:\/\/myserver.com\/share\/db_dump\/miq_pg_dump_.*/)
    end
  end

  context "#restore" do
    before do
      @connect_opts = {:username => 'blah', :password => 'blahblah'}
      @db_opts =      {:dbname => 'vmdb_production', :username => 'root'}
      allow(MiqSmbSession).to receive(:runcmd)
      allow(MiqSmbSession).to receive(:raw_disconnect)
      allow_any_instance_of(MiqSmbSession).to receive(:settings_mount_point).and_return(Rails.root.join("tmp"))
      allow(PostgresAdmin).to receive(:runcmd_with_logging)
      allow(PostgresAdmin).to receive(:pg_dump_file?).and_return(true)
      allow(PostgresAdmin).to receive(:base_backup_file?).and_return(false)

      allow(VmdbDatabaseConnection).to receive(:count).and_return(1)
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

    it "properly logs the result with no :dbname provided" do
      @db_opts.delete(:dbname)
      @db_opts[:local_file] = nil
      remote_backup = "smb://myserver.com/share/pg_backup1.backup"
      @connect_opts[:uri] = remote_backup

      log_stub = instance_double("_log")
      expect(described_class).to receive(:_log).and_return(log_stub)
      expect(log_stub).to        receive(:info).with("[vmdb_production] database has been restored from file: [smb://myserver.com/share/pg_backup1.backup]")

      EvmDatabaseOps.restore(@db_opts, @connect_opts)
    end
  end

  describe "with_mount_session (private method)" do
    let(:db_opts)       { {} }
    let(:connect_opts)  { {} }
    let(:mount_session) { instance_double("MiqGenericMountSession") }

    before do
      allow(MiqGenericMountSession).to receive(:new_session).and_return(mount_session)
    end

    # convenience_wrapper for private method
    def execute_with_mount_session(action = :backup)
      described_class.send(:with_mount_session, action, db_opts, connect_opts) do |dbopts, _session, _remote_file_uri|
        yield dbopts if block_given?
      end
    end

    shared_examples "default with_mount_session behaviors" do
      it "updates db_opts for the block to set the :dbname" do
        execute_with_mount_session do |dbopts|
          expect(dbopts[:dbname]).to eq("vmdb_production")
        end
      end

      context "db_opts[:dbname] is set" do
        it "does not update :dbname if passed" do
          db_opts[:dbname] = "my_db"

          execute_with_mount_session do |dbopts|
            expect(dbopts[:dbname]).to eq("my_db")
          end
        end
      end
    end

    context "with a local file" do
      let(:db_opts) { { :local_file => "/tmp/foo" } }

      include_examples "default with_mount_session behaviors"

      it "does not create a MiqGenericMountSession" do
        expect(MiqGenericMountSession).to_not receive(:new_session)
        execute_with_mount_session
      end

      it "does not try to close a session" do
        expect(mount_session).to_not receive(:disconnect)

        execute_with_mount_session
      end

      it "does not db_opts[:local_file] in the method context" do
        execute_with_mount_session do |dbopts|
          expect(dbopts[:local_file]).to eq("/tmp/foo")
        end
      end

      it "returns the result of the block" do
        expect(execute_with_mount_session { "block result" }).to eq("block result")
      end
    end

    context "without a local file" do
      let(:connect_opts) { { :uri => "smb://tmp/foo" } }

      include_examples "default with_mount_session behaviors"

      before do
        allow(mount_session).to receive(:disconnect)
        # give a slightly different result for this stub so we see a difference
        # in the specs.  This just truncates the scheme from the passed in
        # `uri` arg.
        allow(mount_session).to receive(:uri_to_local_path) { |uri| uri[5..-1] }
      end

      it "creates a MiqGenericMountSession" do
        expect(MiqGenericMountSession).to receive(:new_session)
        execute_with_mount_session
      end

      it "closes the session" do
        expect(mount_session).to receive(:disconnect)

        execute_with_mount_session
      end

      context "for a backup-ish action" do
        let(:backup_file) { "/tmp/bar/baz" }

        before { allow(described_class).to receive(:backup_file_name).and_return(backup_file) }

        it "updates db_opts[:local_file] in the method context" do
          expected_filename = "/tmp/foo/db_backup/baz"

          execute_with_mount_session do |dbopts|
            expect(dbopts[:local_file]).to eq(expected_filename)
          end
        end

        it "respects user passed in connect_opts[:remote_file_name]" do
          expected_filename = "/tmp/foo/db_backup/my_dir/my_backup"
          connect_opts[:remote_file_name] = "/my_dir/my_backup"

          execute_with_mount_session do |dbopts|
            expect(dbopts[:local_file]).to eq(expected_filename)
          end
        end

        it "returns calculated uri" do
          expect(execute_with_mount_session { "block result" }).to eq("smb://tmp/foo/db_backup/baz")
        end
      end

      context "for a restore action" do
        it "updates db_opts[:local_file] in the method context" do
          execute_with_mount_session(:restore) do |dbopts|
            expect(dbopts[:local_file]).to eq("/tmp/foo")
          end
        end

        it "returns calculated uri" do
          expect(execute_with_mount_session(:restore) { "block result" }).to eq("smb://tmp/foo")
        end
      end
    end
  end
end
