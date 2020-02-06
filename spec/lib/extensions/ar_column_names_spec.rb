RSpec.describe "ar_column_names extension" do
  context "With an empty test class" do
    it "should have the correct column names symbols" do
      expect(SchemaMigration.column_names_symbols).to eq([:version])
    end
  end
end
