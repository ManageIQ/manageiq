RSpec.describe ReadOnlyMixin do
  let(:test_class) do
    Class.new(ApplicationRecord) do
      def self.name
        "TestClass"
      end
      # any table with a read_only column
      self.table_name = "classifications"
      include ReadOnlyMixin
    end
  end

  it "doesnt protect regular records" do
    record = test_class.create(:read_only => false)
    record.destroy!
    expect(record).to be_deleted
  end

  it "protects without seeding" do
    record = test_class.create(:read_only => true)
    expect { record.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    expect(record).not_to be_deleted
  end

  it "deletes during seeding" do
    record = test_class.create(:read_only => true)
    EvmDatabase.with_seed do
      record.destroy!
    end
    expect(record).to be_deleted
  end
end
