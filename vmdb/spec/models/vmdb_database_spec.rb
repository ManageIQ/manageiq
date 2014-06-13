require "spec_helper"

describe VmdbDatabase do
  before :each do
    @db    = FactoryGirl.create(:vmdb_database)
    @table = FactoryGirl.create(:vmdb_table_evm,  :vmdb_database => @db, :name => 'accounts')
    @text  = FactoryGirl.create(:vmdb_table_text, :vmdb_database => @db, :name => 'accounts', :parent_id => @table.id)
  end

  it "#evm_tables" do
    @db.evm_tables.should == [@table]
  end

  context ".report_table_bloat" do
    it "will return an array of hashes and verify hash keys for table bloat query" do
      bloat = described_class.report_table_bloat
      bloat.should be_kind_of(Array)

      if bloat.first.kind_of?(Hash)
        expected_keys = ["wasted_size", "wasted_bytes", "wasted_pages", "otta", "table_name", "pages", "pagesize", "percent_bloat", "rows"]
        bloat.first.keys.should have_same_elements(expected_keys)
      end
    end
  end

  context ".report_index_bloat" do
    it "will return an array of hashes and verify hash keys for index bloat query" do
      bloat = described_class.report_index_bloat
      bloat.should be_kind_of(Array)

      if bloat.first.kind_of?(Hash)
        expected_keys = ["wasted_size", "wasted_bytes", "wasted_pages", "otta", "table_name", "pages", "pagesize", "percent_bloat", "rows", "index_name"]
        bloat.first.keys.should have_same_elements(expected_keys)
      end
    end
  end

  context ".report_database_bloat" do
    it "will return an array of hashes and verify hash keys for database bloat query" do
      bloat = described_class.report_database_bloat
      bloat.should be_kind_of(Array)

      if bloat.first.kind_of?(Hash)
        expected_keys = ["wasted_size", "wasted_bytes", "wasted_pages", "otta", "table_name", "pages", "pagesize", "percent_bloat", "rows", "index_name"]
        bloat.first.keys.should have_same_elements(expected_keys)
      end
    end
  end

  context ".report_table_statistics" do
    it "will return an array of hashes and verify hash keys for table statistics query" do
      stats = described_class.report_table_statistics
      stats.should be_kind_of(Array)

      expected_keys = ["table_name", "table_scans", "sequential_rows_read", "index_scans", "index_rows_fetched", "rows_inserted", "rows_updated", "rows_deleted",
                       "rows_hot_updated", "rows_live", "rows_dead", "last_vacuum_date", "last_autovacuum_date", "last_analyze_date", "last_autoanalyze_date"]
      stats.first.keys.should have_same_elements(expected_keys)
    end
  end

  context ".report_table_size" do
    it "will return an array of hashes and verify hash keys for table size query" do
      sizes = described_class.report_table_size
      sizes.should be_kind_of(Array)

      expected_keys = ["table_name", "rows", "size", "pages", "average_row_size"]
      sizes.first.keys.should have_same_elements(expected_keys)
    end
  end

  context ".report_client_connections" do
    it "will return an array of hashes and verify hash keys for client connections query" do
      pending("awaiting CI database upgrade to 9.2.4") if (described_class.connection.send(:postgresql_version) rescue nil).to_i < 90200
      connections = described_class.report_client_connections
      connections.should be_kind_of(Array)

      expected_keys = ["client_address", "database", "spid", "number_waiting", "query"]
      connections.first.keys.should have_same_elements(expected_keys)
    end
  end

  context "#top_tables_by" do
    before :each do
      @table_1 = FactoryGirl.create(:vmdb_table_evm,  :vmdb_database => @db, :name => 'accounts1')
      @table_2 = FactoryGirl.create(:vmdb_table_evm,  :vmdb_database => @db, :name => 'accounts2')
      @table_3 = FactoryGirl.create(:vmdb_table_evm,  :vmdb_database => @db, :name => 'accounts3')
      @table_4 = FactoryGirl.create(:vmdb_table_evm,  :vmdb_database => @db, :name => 'accounts4')
      @table_5 = FactoryGirl.create(:vmdb_table_evm,  :vmdb_database => @db, :name => 'accounts5')
      @table_6 = FactoryGirl.create(:vmdb_table_evm,  :vmdb_database => @db, :name => 'accounts6')
      @table_7 = FactoryGirl.create(:vmdb_table_evm,  :vmdb_database => @db, :name => 'accounts7')

      @metric_1  = FactoryGirl.create(:vmdb_metric,  :resource => @table_1,  :capture_interval_name => 'hourly', :rows => 125,   :size => 15000, :wasted_bytes => 4)
      @metric_2  = FactoryGirl.create(:vmdb_metric,  :resource => @table_2,  :capture_interval_name => 'hourly', :rows => 255,   :size => 10000, :wasted_bytes => 8)
      @metric_3  = FactoryGirl.create(:vmdb_metric,  :resource => @table_3,  :capture_interval_name => 'hourly', :rows => 505,   :size => 5000,  :wasted_bytes => 16)
      @metric_4  = FactoryGirl.create(:vmdb_metric,  :resource => @table_4,  :capture_interval_name => 'hourly', :rows => 1005,  :size => 2000,  :wasted_bytes => 32)
      @metric_5  = FactoryGirl.create(:vmdb_metric,  :resource => @table_5,  :capture_interval_name => 'hourly', :rows => 2005,  :size => 1000,  :wasted_bytes => 64)
      @metric_6  = FactoryGirl.create(:vmdb_metric,  :resource => @table_6,  :capture_interval_name => 'hourly', :rows => 4005,  :size => 500,   :wasted_bytes => 128)
      @metric_7a = FactoryGirl.create(:vmdb_metric,  :resource => @table_7,  :capture_interval_name => 'hourly', :rows => 10005, :size => 150,   :wasted_bytes => 256, :timestamp => 1.hour.ago)
      @metric_7b = FactoryGirl.create(:vmdb_metric,  :resource => @table_7,  :capture_interval_name => 'hourly', :rows => 1,     :size => 150,   :wasted_bytes => 256, :timestamp => 1.minute.ago)
    end

    it "will return a list of ALL tables sorted by number of rows" do
      @db.top_tables_by('rows').should == [@table_6, @table_5, @table_4, @table_3, @table_2, @table_1, @table_7]
    end

    it "will return a list of Top 5 tables sorted by number of rows" do
      @db.top_tables_by('rows', 5).should == [@table_6, @table_5, @table_4, @table_3, @table_2]
    end

    it "will return a list of Top 5 tables sorted by table size (KB)" do
      @db.top_tables_by('size', 5).should == [@table_1, @table_2, @table_3, @table_4, @table_5]
    end

    it "will return a list of Top 2 tables sorted by table size (KB)" do
      @db.top_tables_by('size', 2).should == [@table_1, @table_2]
    end

    it "will return a list of Top 3 tables sorted by wasted bytes" do
      @db.top_tables_by('wasted_bytes', 3).should == [@table_7, @table_6, @table_5]
    end
  end

end
