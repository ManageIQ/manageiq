describe "ar_column_names extension" do
  context "With an empty test class" do
    before(:each) { class ::SchemaMigration < ActiveRecord::Base; end }
    after(:each)  { Object.send(:remove_const, :SchemaMigration) }

    it "should have the correct column names symbols" do
      expect(SchemaMigration.column_names_symbols).to eq([:version])
    end
  end
end
