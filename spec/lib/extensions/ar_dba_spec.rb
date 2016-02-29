describe "ar_dba extension" do
  let(:connection) { ApplicationRecord.connection }

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
