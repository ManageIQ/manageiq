describe VmdbDatabase do
  before do
    @db    = FactoryGirl.create(:vmdb_database)
    @table = FactoryGirl.create(:vmdb_table_evm,  :vmdb_database => @db, :name => 'accounts')
    @text  = FactoryGirl.create(:vmdb_table_text, :vmdb_database => @db, :name => 'accounts', :parent_id => @table.id)
  end

  it "#size" do
    @db.name = ActiveRecord::Base.connection.current_database
    expect(@db.size).to be >= 0
  end

  it "#evm_tables" do
    expect(@db.evm_tables).to eq([@table])
  end

  context ".report_table_bloat" do
    it "will return an array of hashes and verify hash keys for table bloat query" do
      bloat = described_class.report_table_bloat
      expect(bloat).to be_kind_of(Array)

      if bloat.first.kind_of?(Hash)
        expected_keys = ["wasted_size", "wasted_bytes", "wasted_pages", "otta", "table_name", "pages", "pagesize", "percent_bloat", "rows"]
        expect(bloat.first.keys).to match_array(expected_keys)
      end
    end
  end

  context ".report_index_bloat" do
    it "will return an array of hashes and verify hash keys for index bloat query" do
      bloat = described_class.report_index_bloat
      expect(bloat).to be_kind_of(Array)

      if bloat.first.kind_of?(Hash)
        expected_keys = ["wasted_size", "wasted_bytes", "wasted_pages", "otta", "table_name", "pages", "pagesize", "percent_bloat", "rows", "index_name"]
        expect(bloat.first.keys).to match_array(expected_keys)
      end
    end
  end

  context ".report_database_bloat" do
    it "will return an array of hashes and verify hash keys for database bloat query" do
      bloat = described_class.report_database_bloat
      expect(bloat).to be_kind_of(Array)

      if bloat.first.kind_of?(Hash)
        expected_keys = ["wasted_size", "wasted_bytes", "wasted_pages", "otta", "table_name", "pages", "pagesize", "percent_bloat", "rows", "index_name"]
        expect(bloat.first.keys).to match_array(expected_keys)
      end
    end
  end

  context ".report_table_statistics" do
    it "will return an array of hashes and verify hash keys for table statistics query" do
      stats = described_class.report_table_statistics
      expect(stats).to be_kind_of(Array)

      expected_keys = ["table_name", "table_scans", "sequential_rows_read", "index_scans", "index_rows_fetched", "rows_inserted", "rows_updated", "rows_deleted",
                       "rows_hot_updated", "rows_live", "rows_dead", "last_vacuum_date", "last_autovacuum_date", "last_analyze_date", "last_autoanalyze_date"]
      expect(stats.first.keys).to match_array(expected_keys)
    end
  end

  context ".report_table_size" do
    it "will return an array of hashes and verify hash keys for table size query" do
      sizes = described_class.report_table_size
      expect(sizes).to be_kind_of(Array)

      expected_keys = ["table_name", "rows", "size", "pages", "average_row_size"]
      expect(sizes.first.keys).to match_array(expected_keys)
    end
  end

  context ".report_client_connections" do
    it "will return an array of hashes and verify hash keys for client connections query" do
      connections = described_class.report_client_connections
      expect(connections).to be_kind_of(Array)

      expected_keys = ["client_address", "database", "spid", "is_waiting", "query"]
      expect(connections.first.keys).to match_array(expected_keys)

      expect(connections.first['spid']).to be_kind_of(Integer)
    end
  end

  context "#top_tables_by" do
    before do
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
      expect(@db.top_tables_by('rows')).to eq([@table_6, @table_5, @table_4, @table_3, @table_2, @table_1, @table_7])
    end

    it "will return a list of Top 5 tables sorted by number of rows" do
      expect(@db.top_tables_by('rows', 5)).to eq([@table_6, @table_5, @table_4, @table_3, @table_2])
    end

    it "will return a list of Top 5 tables sorted by table size (KB)" do
      expect(@db.top_tables_by('size', 5)).to eq([@table_1, @table_2, @table_3, @table_4, @table_5])
    end

    it "will return a list of Top 2 tables sorted by table size (KB)" do
      expect(@db.top_tables_by('size', 2)).to eq([@table_1, @table_2])
    end

    it "will return a list of Top 3 tables sorted by wasted bytes" do
      expect(@db.top_tables_by('wasted_bytes', 3)).to eq([@table_7, @table_6, @table_5])
    end
  end

  describe '#has_perf_data?' do
    subject { @db.has_perf_data? }

    context 'without metrics' do
      it { is_expected.to be_falsey }
    end

    context 'with metrics' do
      before do
        @db.vmdb_database_metrics = [FactoryGirl.create(:vmdb_database_metric, :capture_interval_name => 'hourly')]
      end

      it { is_expected.to be_truthy }
    end
  end
end
