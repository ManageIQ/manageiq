describe UuidMixin do
  let(:test_class) do
    Class.new(ActiveRecord::Base) do
      def self.name; "TestClass"; end
      self.table_name = "service_templates"
      include UuidMixin
    end
  end

  let(:service_template) { FactoryBot.create(:service_template) }
  let(:dialog_field) { FactoryBot.create(:dialog_field) }

  context 'with dup overriden' do
    it 'resets guid' do
      expect(service_template.dup.guid).not_to eq(service_template.guid)
    end
  end
end
