describe "ar_dba extension" do
  let(:connection) { ApplicationRecord.connection }

  describe "#primary_key_index" do
    it "returns nil when there is no primary key" do
      table_name = "no_pk_test"
      connection.select_value("CREATE TABLE #{table_name} (id INTEGER)")
      expect(connection.primary_key_index(table_name)).to be nil
    end

    it "returns the correct primary key" do
      index_def = connection.primary_key_index("miq_databases")
      expect(index_def.table).to eq("miq_databases")
      expect(index_def.unique).to be true
      expect(index_def.columns).to eq(["id"])
    end

    it "works with composite primary keys" do
      table_name = "comp_pk_test"
      connection.select_value("CREATE TABLE #{table_name} (id1 INTEGER, id2 INTEGER)")
      connection.select_value("ALTER TABLE #{table_name} ADD PRIMARY KEY (id1, id2)")

      index_def = connection.primary_key_index(table_name)
      expect(index_def.table).to eq(table_name)
      expect(index_def.unique).to be true
      expect(index_def.columns).to match_array(%w(id1 id2))
    end
  end

  describe "#primary_key?" do
    it "returns false for a table without a primary key" do
      table_name = "no_pk_test"
      connection.select_value("CREATE TABLE #{table_name} (id INTEGER)")
      expect(connection.primary_key?(table_name)).to be false
    end

    it "returns true for a table with a primary key" do
      expect(connection.primary_key?("miq_databases")).to be true
    end

    it "returns true for composite primary keys" do
      expect(connection.primary_key?("storages_vms_and_templates")).to be true
    end
  end
end
