describe GenericObjectDefinition do
  let(:definition) do
    FactoryGirl.create(
      :generic_object_definition,
      :name       => "test_definition",
      :properties => {
        :attributes => {
          :max_number => "integer",
          :server     => "string",
          :flag       => "boolean",
          :data_read  => "float",
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

  describe '#type_cast' do
    it 'casts a string to a predefined type' do
      expect(definition.type_cast('max_number', '100')).to eq(100)
    end
  end
end
