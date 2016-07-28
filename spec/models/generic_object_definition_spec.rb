describe GenericObjectDefinition do
  let(:definition) do
    FactoryGirl.create(
      :generic_object_definition,
      :name       => "test_definition",
      :properties => {
        :attributes => {
          :data_read  => "float",
          :flag       => "boolean",
          :max_number => "integer",
          :server     => "string",
          :s_time     => "datetime"
        }
      }
    )
  end

  it 'requires name attribute present' do
    expect(described_class.new).not_to be_valid
  end

  it 'requires name attribute to be unique' do
    described_class.create!(:name => 'myclass')
    expect(described_class.new(:name => 'myclass')).not_to be_valid
  end

  it 'raises an error if any property attribute is not of a recognized type' do
    testdef = described_class.new(:name => 'test')
    expect { testdef.properties = {:attributes => {'myattr' => :strange_type}} }.to raise_error(ArgumentError)
  end

  describe '#destroy' do
    let(:generic_object) do
      FactoryGirl.build(:generic_object, :generic_object_definition => definition, :name => 'test')
    end

    it 'raises an error if the definition is in use' do
      generic_object.save!
      expect { definition.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe '#create_object' do
    it 'creates a generic object' do
      obj = definition.create_object(:name => 'test', :max_number => 100)
      expect(obj).to be_a_kind_of(GenericObject)
      expect(obj.generic_object_definition).to eq(definition)
      expect(obj.max_number).to eq(100)
    end
  end
end
