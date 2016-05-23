describe VmdbTable do
  context "#seed_indexes" do
    before(:each) do
      @db = VmdbDatabase.seed_self
      @vmdb_table = FactoryGirl.create(:vmdb_table, :vmdb_database => @db, :name => 'foo')
    end

    it "adds new indexes" do
      index_names = ['flintstones']
      index_results = index_names.collect do |i|
        index = double('sql_index')
        allow(index).to receive(:name).and_return(i)
        index
      end
      allow(@vmdb_table).to receive(:sql_indexes).and_return(index_results)
      @vmdb_table.seed_indexes
      expect(@vmdb_table.vmdb_indexes.collect(&:name)).to eq(index_names)
    end

    it "removes deleted indexes" do
      index_names = ['flintstones']
      index_names.each { |i| FactoryGirl.create(:vmdb_index, :vmdb_table => @vmdb_table, :name => i) }
      @vmdb_table.reload
      expect(@vmdb_table.vmdb_indexes.collect(&:name)).to eq(index_names)

      allow(@vmdb_table).to receive(:sql_indexes).and_return([])
      @vmdb_table.seed_indexes
      @vmdb_table.reload
      expect(@vmdb_table.vmdb_indexes.collect(&:name)).to eq([])
    end

    it "finds existing indexes" do
      index_names = ['flintstones']
      index_results = index_names.collect do |i|
        index = double('sql_index')
        allow(index).to receive(:name).and_return(i)
        index
      end
      index_names.each { |i| FactoryGirl.create(:vmdb_index, :vmdb_table => @vmdb_table, :name => i) }
      allow(@vmdb_table).to receive(:sql_indexes).and_return(index_results)
      @vmdb_table.seed_indexes
      @vmdb_table.reload
      expect(@vmdb_table.vmdb_indexes.collect(&:name)).to eq(index_names)
    end
  end
end
