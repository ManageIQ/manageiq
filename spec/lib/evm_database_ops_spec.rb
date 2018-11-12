require 'util/runcmd'
describe EvmDatabaseOps do
  let(:file_storage) { double("MiqSmbSession", :disconnect => nil) }
  let(:local_backup) { "/tmp/backup_1" }
  let(:input_path)   { "foo/bar/mkfifo" }
  let(:run_db_ops)   { @db_opts.dup.merge(:local_file => input_path) }
  let(:tmpdir)       { Rails.root.join("tmp") }

  before do
    allow(MiqFileStorage).to receive(:with_interface_class).and_yield(file_storage)
  end

  context "#backup" do
    before do
      @connect_opts = {:username => 'blah', :password => 'blahblah', :uri => "smb://myserver.com/share"}
      @db_opts      = {:username => 'root', :dbname => 'vmdb_production' }
      allow(file_storage).to   receive(:settings_mount_point).and_return(tmpdir.to_s)
      allow(file_storage).to   receive(:uri_to_local_path).and_return(tmpdir.join("share").to_s)
      allow(file_storage).to   receive(:add).and_yield(input_path)

      allow(FileUtils).to      receive(:mv).and_return(true)
      allow(EvmDatabaseOps).to receive(:backup_destination_free_space).and_return(200.megabytes)
      allow(EvmDatabaseOps).to receive(:database_size).and_return(100.megabytes)
    end

    it "locally" do
      @db_opts[:local_file] = local_backup
      expect(PostgresAdmin).to receive(:backup).with(run_db_ops)
      expect(EvmDatabaseOps.backup(@db_opts, @connect_opts)).to eq(local_backup)
    end

    it "defaults" do
      @db_opts[:local_file] = local_backup
      expect(PostgresAdmin).to receive(:backup).with(run_db_ops)
      expect(EvmDatabaseOps.backup(@db_opts, {})).to eq(local_backup)
    end

    it "splits files with a local file" do
      @db_opts[:local_file] = local_backup
      @db_opts[:byte_count] = "200M"

      allow(file_storage).to   receive(:send).with(:add, local_backup, "200M").and_yield(input_path)
      expect(PostgresAdmin).to receive(:backup).with(run_db_ops)
      EvmDatabaseOps.backup(@db_opts, {})
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
      expect(PostgresAdmin).to receive(:backup).with(run_db_ops)
      expect(EvmDatabaseOps.backup(@db_opts, @connect_opts)).to eq("smb://myserver.com/share/db_backup/custom_backup")
    end

    it "remotely without a remote file name" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = nil
      expect(PostgresAdmin).to receive(:backup).with(run_db_ops)
      expect(EvmDatabaseOps.backup(@db_opts, @connect_opts)).to match(/smb:\/\/myserver.com\/share\/db_backup\/miq_backup_.*/)
    end

    it "properly logs the result with no :dbname provided" do
      @db_opts.delete(:dbname)
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = nil
      run_db_ops[:dbname] = "vmdb_production"
      allow(described_class).to receive(:backup_file_name).and_return("miq_backup")
      expect(PostgresAdmin).to receive(:backup).with(run_db_ops)

      log_stub = instance_double("_log")
      expect(described_class).to receive(:_log).twice.and_return(log_stub)
      expect(log_stub).to        receive(:info).with(any_args)
      expect(log_stub).to        receive(:info).with("[vmdb_production] database has been backed up to file: [smb://myserver.com/share/db_backup/miq_backup]")

      EvmDatabaseOps.backup(@db_opts, @connect_opts)
    end
  end

  context "#dump" do
    let(:local_dump) { "/tmp/dump_1" }
    before do
      @connect_opts = {:username => 'blah', :password => 'blahblah', :uri => "smb://myserver.com/share"}
      @db_opts =      {:dbname => 'vmdb_production', :username => 'root'}
      allow(MiqSmbSession).to receive(:runcmd)
      allow(file_storage).to  receive(:settings_mount_point).and_return(tmpdir)
      allow(file_storage).to  receive(:add).and_yield(input_path)

      allow(MiqUtil).to        receive(:runcmd)
      allow(PostgresAdmin).to  receive(:runcmd_with_logging)
      allow(FileUtils).to      receive(:mv).and_return(true)
      allow(EvmDatabaseOps).to receive(:backup_destination_free_space).and_return(200.megabytes)
      allow(EvmDatabaseOps).to receive(:database_size).and_return(100.megabytes)
    end

    it "locally" do
      @db_opts[:local_file] = local_dump
      expect(PostgresAdmin).to receive(:backup_pg_dump).with(run_db_ops)
      expect(EvmDatabaseOps.dump(@db_opts, @connect_opts)).to eq(local_dump)
    end

    it "defaults" do
      @db_opts[:local_file] = local_dump
      expect(PostgresAdmin).to receive(:backup_pg_dump).with(run_db_ops)
      expect(EvmDatabaseOps.dump(@db_opts, {})).to eq(local_dump)
    end

    it "splits files with a local file" do
      @db_opts[:local_file] = local_dump
      @db_opts[:byte_count] = "200M"

      allow(file_storage).to   receive(:send).with(:add, local_dump, "200M").and_yield(input_path)
      expect(PostgresAdmin).to receive(:backup_pg_dump).with(run_db_ops)
      EvmDatabaseOps.dump(@db_opts, {})
    end

    it "without enough free space" do
      EvmSpecHelper.create_guid_miq_server_zone
      allow(EvmDatabaseOps).to receive(:backup_destination_free_space).and_return(100.megabytes)
      allow(EvmDatabaseOps).to receive(:database_size).and_return(200.megabytes)
      expect(PostgresAdmin).to receive(:backup_pg_dump).never
      expect { EvmDatabaseOps.dump(@db_opts, @connect_opts) }.to raise_error(MiqException::MiqDatabaseBackupInsufficientSpace)
      expect(MiqQueue.where(:class_name => "MiqEvent", :method_name => "raise_evm_event").count).to eq(1)
    end

    it "remotely" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = "custom_pg_dump"
      expect(PostgresAdmin).to receive(:backup_pg_dump).with(run_db_ops)
      expect(EvmDatabaseOps.dump(@db_opts, @connect_opts)).to eq("smb://myserver.com/share/db_dump/custom_pg_dump")
    end

    it "remotely without a remote file name" do
      @db_opts[:local_file] = nil
      @connect_opts[:remote_file_name] = nil
      expect(PostgresAdmin).to receive(:backup_pg_dump).with(run_db_ops)
      expect(EvmDatabaseOps.dump(@db_opts, @connect_opts)).to match(/smb:\/\/myserver.com\/share\/db_dump\/miq_pg_dump_.*/)
    end
  end

  context "#restore" do
    before do
      @connect_opts = {:username => 'blah', :password => 'blahblah'}
      @db_opts =      {:dbname => 'vmdb_production', :username => 'root'}

      allow(MiqSmbSession).to receive(:runcmd)
      allow(MiqSmbSession).to receive(:raw_disconnect)
      allow(file_storage).to  receive(:settings_mount_point).and_return(tmpdir)
      allow(file_storage).to  receive(:magic_number_for).and_return(:pgdump)
      allow(file_storage).to  receive(:download).and_yield(input_path)

      allow(PostgresAdmin).to receive(:runcmd_with_logging)

      allow(VmdbDatabaseConnection).to receive(:count).and_return(1)
    end

    it "from local backup" do
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

  describe "with_file_storage (private method)" do
    let(:db_opts)       { {} }
    let(:connect_opts)  { {} }

    # convenience_wrapper for private method
    def execute_with_file_storage(action = :backup)
      described_class.send(:with_file_storage, action, db_opts, connect_opts) do |dbopts|
        yield dbopts if block_given?
      end
    end

    shared_examples "default with_file_storage behaviors" do
      it "sets dbopts[:local_file] to the input_path" do
        execute_with_file_storage do |dbopts|
          expect(dbopts[:local_file]).to eq(input_path)
        end
      end

      it "updates db_opts for the block to set the :dbname" do
        execute_with_file_storage do |dbopts|
          expect(dbopts[:dbname]).to eq("vmdb_production")
        end
      end

      context "db_opts[:dbname] is set" do
        it "does not update :dbname if passed" do
          db_opts[:dbname] = "my_db"

          execute_with_file_storage do |dbopts|
            expect(dbopts[:dbname]).to eq("my_db")
          end
        end
      end
    end

    context "with a local file" do
      let(:db_opts) { { :local_file => "/tmp/foo" } }

      before { expect(file_storage).to receive(:add).and_yield(input_path) }

      include_examples "default with_file_storage behaviors"

      it "always uses a file_storage interface" do
        execute_with_file_storage do
          expect(file_storage).to receive(:test_method)
          file_storage.test_method
        end
      end

      it "does not try to close a session" do
        expect(file_storage).to_not receive(:disconnect)

        execute_with_file_storage
      end

      it "updates the db_opts[:local_file] to the file_storage fifo" do
        execute_with_file_storage do |dbopts|
          expect(dbopts[:local_file]).to eq(input_path)
        end
      end

      it "returns the result of the block" do
        expect(execute_with_file_storage { "block result" }).to eq(db_opts[:local_file])
      end
    end

    context "without a local file" do
      let(:connect_opts) { { :uri => "smb://tmp/foo" } }

      before { allow(file_storage).to receive(:add).and_yield(input_path) }

      include_examples "default with_file_storage behaviors"

      context "for a backup-ish action" do
        let(:backup_file) { "/tmp/bar/baz" }

        before { allow(described_class).to receive(:backup_file_name).and_return(backup_file) }

        it "updates db_opts[:local_file] in the method context" do
          expected_uri = "smb://tmp/foo/db_backup/baz"

          expect(file_storage).to receive(:send).with(:add, expected_uri)
          execute_with_file_storage
        end

        it "respects user passed in connect_opts[:remote_file_name]" do
          expected_uri = "smb://tmp/foo/db_backup/my_dir/my_backup"
          connect_opts[:remote_file_name] = "/my_dir/my_backup"

          expect(file_storage).to receive(:send).with(:add, expected_uri)
          execute_with_file_storage
        end

        it "returns calculated uri" do
          expect(execute_with_file_storage { "block result" }).to eq("smb://tmp/foo/db_backup/baz")
        end

        it "yields `db_opt`s only" do
          allow(file_storage).to receive(:download) { |&block| block.call(input_path) }
          expect do |rspec_probe|
            described_class.send(:with_file_storage, :backup, db_opts, connect_opts, &rspec_probe)
          end.to yield_with_args(:dbname => "vmdb_production", :local_file => input_path)
        end
      end

      context "for a restore action" do
        before { expect(file_storage).to receive(:magic_number_for).and_return(:pgdump) }

        it "updates db_opts[:local_file] in the method context" do
          expect(file_storage).to receive(:send).with(:download, nil, "smb://tmp/foo")
          execute_with_file_storage(:restore)
        end

        it "parses the dirname of the `uri` and passes that in `connect_opts`" do
          expected_connect_opts = { :uri => "smb://tmp/" }
          allow(file_storage).to receive(:download)
          expect(MiqFileStorage).to receive(:with_interface_class).with(expected_connect_opts)
          execute_with_file_storage(:restore)
        end

        it "returns calculated uri" do
          allow(file_storage).to receive(:download).and_yield(input_path)
          expect(execute_with_file_storage(:restore) { "block result" }).to eq("smb://tmp/foo")
        end

        it "yields `backup_type` along with `db_opt`s" do
          allow(file_storage).to receive(:download) { |&block| block.call(input_path) }
          expected_yield_args = [
            { :dbname => "vmdb_production", :local_file => input_path },
            :pgdump
          ]
          expect do |rspec_probe|
            described_class.send(:with_file_storage, :restore, db_opts, connect_opts, &rspec_probe)
          end.to yield_with_args(*expected_yield_args)
        end

        context "with query_params in the URI" do
          let(:connect_opts) { { :uri => "swift://container/foo.gz?2plus2=5" } }

          it "retains query_params when parsing dirname" do
            expected_connect_opts = { :uri => "swift://container/?2plus2=5" }
            allow(file_storage).to receive(:download)
            expect(MiqFileStorage).to receive(:with_interface_class).with(expected_connect_opts)
            execute_with_file_storage(:restore)
          end
        end
      end
    end
  end
end
