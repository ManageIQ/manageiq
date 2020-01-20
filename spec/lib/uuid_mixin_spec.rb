RSpec.describe UuidMixin do
  let(:test_class) do
    Class.new(ActiveRecord::Base) do
      def self.name; "TestClass"; end
      self.table_name = "service_templates"
      include UuidMixin
    end
  end

  it '#dup resets guid' do
    original = test_class.create!
    expect(original.guid).to be_guid

    duplicate = original.dup.tap(&:save!)
    expect(duplicate).to be_valid
    expect(duplicate.guid).to be_guid
    expect(duplicate.guid).not_to eq(original.guid)
  end
end
