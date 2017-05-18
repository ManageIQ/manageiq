require_migration
describe AddValueSerializedToCustomAttribute do
  let(:custom_attribute_stub) { migration_stub(:CustomAttribute) }

  migration_context :up do
    it 'migrate current values to serialized values correctly' do
      custom_attribute_stub.create!(:name => 'example', :value => "foo")
      migrate
      expect(YAML.load(custom_attribute_stub.find_by(:name => 'example').serialized_value)).to eq("foo")
    end
  end
end
