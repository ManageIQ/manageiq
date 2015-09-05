require "spec_helper"

describe VmdbTable do
  context "#capture_metrics" do
    before(:each) do
      MiqDatabase.seed
      VmdbDatabase.seed
      # works with VmdbTableEvm, VmdbIndex(often not present), but not VmdbTableText
      @table = VmdbTable.where(:type => 'VmdbTableEvm').first
      @table.capture_metrics
    end

    it "populates vmdb_metrics columns" do
      metrics = @table.vmdb_metrics
      metrics.length.should == 0

      @table.capture_metrics
      metrics = @table.vmdb_metrics
      metrics.length.should_not == 0

      metric = metrics.first
      columns = %w{ size rows pages percent_bloat wasted_bytes otta table_scans sequential_rows_read
          index_scans index_rows_fetched rows_inserted rows_updated rows_deleted rows_hot_updated rows_live
          rows_dead timestamp
      }
      columns.each do |column|
        metric.send(column).should_not be_nil
      end
    end
  end

  context "#seed_indexes" do
    before(:each) do
      @db = VmdbDatabase.seed_self
      @vmdb_table = FactoryGirl.create(:vmdb_table, :vmdb_database => @db, :name => 'foo')
    end

    it "adds new indexes" do
      index_names = ['flintstones']
      index_results = index_names.collect do |i|
        index = double('sql_index')
        index.stub(:name).and_return(i)
        index
      end
      @vmdb_table.stub(:sql_indexes).and_return(index_results)
      @vmdb_table.seed_indexes
      @vmdb_table.vmdb_indexes.collect(&:name).should == index_names
    end

    it "removes deleted indexes" do
      index_names = ['flintstones']
      index_names.each { |i| FactoryGirl.create(:vmdb_index, :vmdb_table => @vmdb_table, :name => i) }
      @vmdb_table.reload
      @vmdb_table.vmdb_indexes.collect(&:name).should == index_names

      @vmdb_table.stub(:sql_indexes).and_return([])
      @vmdb_table.seed_indexes
      @vmdb_table.reload
      @vmdb_table.vmdb_indexes.collect(&:name).should == []
    end

    it "finds existing indexes" do
      index_names = ['flintstones']
      index_results = index_names.collect do |i|
        index = double('sql_index')
        index.stub(:name).and_return(i)
        index
      end
      index_names.each { |i| FactoryGirl.create(:vmdb_index, :vmdb_table => @vmdb_table, :name => i) }
      @vmdb_table.stub(:sql_indexes).and_return(index_results)
      @vmdb_table.seed_indexes
      @vmdb_table.reload
      @vmdb_table.vmdb_indexes.collect(&:name).should == index_names
    end
  end
end
