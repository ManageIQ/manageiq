describe VmdbDatabase do
  context "::Seeding" do
    include_examples(".seed called multiple times")
    let(:connection) { ApplicationRecord.connection }

    it ".seed" do
      MiqDatabase.seed
      vmdb_database = double('vmdb_database')
      allow(described_class).to receive(:seed_self).and_return(vmdb_database)
      expect(vmdb_database).to receive(:seed)
      described_class.seed
    end

    context "#seed" do
      before(:each) do
        MiqDatabase.seed
        @db = FactoryGirl.create(:vmdb_database)
      end

      it "adds new tables" do
        connection.select_value("CREATE TABLE flintstones (id BIGINT PRIMARY KEY)")
        expect(@db.evm_tables.collect(&:name)).not_to include("flintstones")
        @db.seed
        expect(@db.evm_tables.collect(&:name)).to include("flintstones")
      end

      it "removes deleted tables" do
        table = 'flintstones'
        FactoryGirl.create(:vmdb_table_evm, :vmdb_database => @db, :name => table)
        @db.reload
        expect(@db.evm_tables.collect(&:name)).to include(table)

        @db.seed
        @db.reload
        expect(@db.evm_tables.collect(&:name)).not_to include(table)
      end

      it "finds existing tables" do
        table = 'flintstones'
        connection.select_value("CREATE TABLE #{table} (id BIGINT PRIMARY KEY)")
        FactoryGirl.create(:vmdb_table_evm, :vmdb_database => @db, :name => table)

        expect(VmdbTableEvm).to receive(:create).never
        @db.seed
        expect(@db.evm_tables.collect(&:name)).to include(table)
      end
    end

    context ".seed_self" do
      it "should have empty table before seeding" do
        expect(described_class.in_my_region.count).to eq(0)
      end

      it "should have only one record" do
        described_class.seed_self
        expect(described_class.in_my_region.count).to eq(1)
      end

      it "should have populated columns" do
        described_class.seed_self
        db = described_class.my_database
        columns =  %w( name vendor version  )
        connection = ActiveRecord::Base.connection
        columns << 'ipaddress'       if connection.respond_to?(:server_ip_address)
        columns << 'data_directory'  if connection.respond_to?(:data_directory)
        columns << 'last_start_time' if connection.respond_to?(:last_start_time)

        db.update_attributes(:data_directory => "stubbed")

        columns.each do |column|
          expect(db.send(column)).not_to be_nil
        end
      end

      it "should not update table values" do
        factory_ip_address = "127.0.0.1"
        FactoryGirl.create(:vmdb_database, :ipaddress => factory_ip_address)

        stubbed_ip_address = "127.0.0.1"
        allow(described_class).to receive(:db_server_ipaddress).and_return(stubbed_ip_address)
        described_class.seed_self

        db = described_class.my_database
        expect(db.ipaddress).to eq(stubbed_ip_address)
      end

      it "should update table values" do
        factory_ip_address = "127.0.0.1"
        FactoryGirl.create(:vmdb_database, :ipaddress => factory_ip_address)

        stubbed_ip_address = "192.255.255.1"
        allow(described_class).to receive(:db_server_ipaddress).and_return(stubbed_ip_address)
        described_class.seed_self

        db = described_class.my_database
        expect(db.ipaddress).to eq(stubbed_ip_address)
      end
    end
  end
end
