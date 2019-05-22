describe VmdbDatabase do
  describe "::Seeding" do
    let(:connection) { ApplicationRecord.connection }

    describe ".seed" do
      let!(:db) { described_class.seed }

      # This test is intentionally long winded instead of breaking it up into
      # multiple tests per concern because of how long a full seed takes.
      # Breaking it into individual tests would increase runtime a lot.
      it "creates tables, text_tables, and indexes" do
        # collects everything
        expect(db.evm_tables).to_not  be_empty
        expect(db.text_tables).to_not be_empty

        # creates a table correctly
        table = db.evm_tables.find_by(:name => "accounts")
        expect(table).to be_kind_of(VmdbTableEvm)

        # relates indexes and text tables to the table
        expect(table.text_tables).to_not be_empty
        expect(table.vmdb_indexes).to_not be_empty

        # creates an index correctly
        index = table.vmdb_indexes.first
        expect(index).to be_kind_of(VmdbIndex)

        # creates primary keys
        expect(table.vmdb_indexes.sort.first.name).to eq("accounts_pkey")
        # creates non-primary key indexes
        expect(table.vmdb_indexes.sort.last.name).to  start_with("index_")

        # creates a text table correctly
        text_table = table.text_tables.first
        expect(text_table).to be_kind_of(VmdbTableText)

        # relates indexes to the text tables
        expect(text_table.vmdb_indexes).to_not be_empty

        # creates a text table's index correctly
        text_table_index = text_table.vmdb_indexes.first
        expect(text_table_index).to be_kind_of(VmdbIndex)

        # called twice should not change table contents
        dbs     = described_class.all.to_a
        tables  = VmdbTable.pluck(:name)
        indexes = VmdbIndex.pluck(:name)

        expect(described_class).to receive(:create).never
        expect(VmdbTable).to       receive(:create).never
        expect(VmdbIndex).to       receive(:create).never

        described_class.seed

        expect(described_class.all.to_a).to eq(dbs)
        expect(tables).to  match_array(VmdbTable.pluck(:name))
        expect(indexes).to match_array(VmdbIndex.pluck(:name))
      end
    end

    describe ".seed_self (private)" do
      it "should have populated columns" do
        expect(described_class).to receive(:db_server_ipaddress).and_return("192.255.255.1")

        t = 1.week.ago
        expect(connection).to receive(:data_directory).and_return("/usr/local/var/postgres")
        expect(connection).to receive(:last_start_time).and_return(t)

        db = described_class.send(:seed_self)

        expect(db.name).to     eq(connection.current_database)
        expect(db.vendor).to   eq(connection.adapter_name)
        expect(db.version).to  eq(connection.database_version)

        expect(db.ipaddress).to       eq("192.255.255.1")
        expect(db.data_directory).to  eq("/usr/local/var/postgres")
        expect(db.last_start_time).to eq(t)
      end

      it "should update table values" do
        FactoryBot.create(:vmdb_database, :ipaddress => "127.0.0.1")

        expect(described_class).to receive(:db_server_ipaddress).and_return("192.255.255.1")

        db = described_class.send(:seed_self)

        expect(db.ipaddress).to eq("192.255.255.1")
      end

      it "returns nil for the data disk name if it cannot be determined" do
        allow(::Sys::Filesystem).to receive(:mount_point).with(any_args).and_raise(Errno::EACCES)
        db = described_class.send(:seed_self)
        expect(db.data_disk).to be_nil
      end
    end

    describe ".seed_tables (private)" do
      let!(:db) { FactoryBot.create(:vmdb_database) }

      before { described_class.send(:seed_tables) }

      it "adds new tables" do
        connection.execute("CREATE TABLE flintstones (id BIGINT PRIMARY KEY)")

        described_class.send(:seed_tables)

        expect(db.reload.evm_tables.pluck(:name)).to include("flintstones")
      end

      it "removes deleted tables" do
        FactoryBot.create(:vmdb_table_evm, :vmdb_database => db, :name => "flintstones")

        described_class.send(:seed_tables)

        expect(db.reload.evm_tables.pluck(:name)).not_to include("flintstones")
      end

      it "updates existing tables" do
        connection.execute("CREATE TABLE flintstones (id BIGINT PRIMARY KEY)")
        FactoryBot.create(:vmdb_table_evm, :vmdb_database => db, :name => "flintstones")

        expect(VmdbTableEvm).to receive(:create).never

        described_class.send(:seed_tables)

        expect(db.reload.evm_tables.pluck(:name)).to include("flintstones")
      end
    end

    describe ".seed_indexes (private)" do
      let!(:db)    { FactoryBot.create(:vmdb_database) }
      let!(:table) { FactoryBot.create(:vmdb_table_evm, :vmdb_database => db, :name => "accounts") }

      before { described_class.send(:seed_indexes) }

      it "adds new indexes" do
        connection.execute("CREATE INDEX index_flintstones ON accounts (id)")

        described_class.send(:seed_indexes)

        expect(db.reload.vmdb_indexes.pluck(:name)).to    include("index_flintstones")
        expect(table.reload.vmdb_indexes.pluck(:name)).to include("index_flintstones")
      end

      it "removes deleted indexes" do
        FactoryBot.create(:vmdb_index, :vmdb_table => table, :name => "index_flintstones")

        described_class.send(:seed_indexes)

        expect(db.reload.vmdb_indexes.pluck(:name)).not_to    include("index_flintstones")
        expect(table.reload.vmdb_indexes.pluck(:name)).not_to include("index_flintstones")
      end

      it "updates existing indexes" do
        connection.execute("CREATE INDEX index_flintstones ON accounts (id)")
        FactoryBot.create(:vmdb_index, :vmdb_table => table, :name => "index_flintstones")

        expect(VmdbIndex).to receive(:create).never

        described_class.send(:seed_indexes)

        expect(db.reload.vmdb_indexes.pluck(:name)).to    include("index_flintstones")
        expect(table.reload.vmdb_indexes.pluck(:name)).to include("index_flintstones")
      end
    end
  end
end
