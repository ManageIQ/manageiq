describe Service::DialogProperties do
  it 'with a nil parameter' do
    options = nil
    expect(described_class.parse(options)).to eq({})
  end

  it 'with an empty hash' do
    options = {}
    expect(described_class.parse(options)).to eq({})
  end

  context 'name' do
    it 'with an empty name' do
      options = {'dialog_service_name' => ' '}
      expect(described_class.parse(options)).to eq({})
    end

    it 'with option name' do
      options = {'dialog_service_name' => 'name from dialog'}
      expect(described_class.parse(options)).to eq(:name => 'name from dialog')
    end
  end

  context 'description' do
    it 'with an empty description' do
      options = {'dialog_service_description' => ' '}
      expect(described_class.parse(options)).to eq({})
    end

    it 'with option description' do
      options = {'dialog_service_description' => 'test description from dialog'}
      expect(described_class.parse(options)).to eq(:description => 'test description from dialog')
    end
  end
end
