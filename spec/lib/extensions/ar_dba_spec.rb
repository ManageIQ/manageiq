RSpec.describe "ar_dba extension" do
  let(:connection) { ApplicationRecord.connection }

  describe "#xlog_location" do
    it "returns a valid lsn" do
      expect(connection.xlog_location).to match(%r{\h+/\h+})
    end
  end

  describe "#xlog_location_diff" do
    it "returns the correct xlog difference" do
      expect(connection.xlog_location_diff("18/72F84A48", "18/72F615B8")). to eq(144_528)
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
  end
end
