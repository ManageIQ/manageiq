require "spec_helper"

describe VmdbDatabase do
  context "::Seeding" do
    it ".seed" do
      MiqDatabase.seed
      vmdb_database = double('vmdb_database')
      described_class.stub(:seed_self).and_return(vmdb_database)
      vmdb_database.should_receive(:seed)
      described_class.seed
    end

    context "#seed" do
      before(:each) do
        MiqDatabase.seed
        @db = FactoryGirl.create(:vmdb_database)
      end

      it "adds new tables" do
        table_names = ['flintstones']
        described_class.connection.stub(:tables).and_return(table_names)
        @db.seed
        @db.evm_tables.collect(&:name).should == table_names
      end

      it "removes deleted tables" do
        table_names = ['flintstones']
        table_names.each { |t| FactoryGirl.create(:vmdb_table_evm, :vmdb_database => @db, :name => t) }
        @db.reload
        @db.evm_tables.collect(&:name).should == table_names

        described_class.connection.stub(:tables).and_return([])
        @db.seed
        @db.reload
        @db.evm_tables.collect(&:name).should == []
      end

      it "finds existing tables" do
        table_names = ['flintstones']
        table_names.each { |t| FactoryGirl.create(:vmdb_table_evm, :vmdb_database => @db, :name => t) }
        described_class.connection.stub(:tables).and_return(table_names)
        VmdbTableEvm.should_receive(:create).never
        @db.seed
        @db.evm_tables.collect(&:name).should == table_names
      end

    end


    context ".seed_self" do
      it "should have empty table before seeding" do
        described_class.in_my_region.count.should == 0
      end

      it "should have only one record" do
        described_class.seed_self
        described_class.in_my_region.count.should == 1
      end

      it "should have populated columns" do
        described_class.seed_self
        db = described_class.my_database
        columns =  %w{ name vendor version  }
        connection = ActiveRecord::Base.connection
        columns << 'ipaddress'       if connection.respond_to?(:server_ip_address)
        columns << 'data_directory'  if connection.respond_to?(:data_directory)
        columns << 'last_start_time' if connection.respond_to?(:last_start_time)

        db.update_attributes(:data_directory => "stubbed")

        columns.each do |column|
          db.send(column).should_not be_nil
        end
      end

      it "should not update table values" do
        factory_ip_address = "127.0.0.1"
        FactoryGirl.create(:vmdb_database, :ipaddress => factory_ip_address)

        stubbed_ip_address = "127.0.0.1"
        described_class.stub(:db_server_ipaddress).and_return(stubbed_ip_address)
        described_class.seed_self

        db = described_class.my_database
        db.ipaddress.should == stubbed_ip_address
      end

      it "should update table values" do
        factory_ip_address = "127.0.0.1"
        FactoryGirl.create(:vmdb_database, :ipaddress => factory_ip_address)

        stubbed_ip_address = "192.255.255.1"
        described_class.stub(:db_server_ipaddress).and_return(stubbed_ip_address)
        described_class.seed_self

        db = described_class.my_database
        db.ipaddress.should == stubbed_ip_address
      end

    end

  end
end
