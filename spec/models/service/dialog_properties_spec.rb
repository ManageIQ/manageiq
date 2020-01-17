RSpec.describe Service::DialogProperties do
  it 'with a nil parameter and nil user' do
    options = nil
    expect(described_class.parse(options, nil)).to eq({})
  end

  it 'with an empty hash parameter and nil user' do
    options = {}
    expect(described_class.parse(options, nil)).to eq({})
  end

  it 'will call the Retirement class' do
    expect(Service::DialogProperties::Retirement).to receive(:parse).with({}, nil).and_return({})
    described_class.parse(nil, nil)
  end

  describe 'name' do
    it 'with an empty name' do
      options = {'dialog_service_name' => ' '}
      expect(described_class.parse(options, nil)).to eq({})
    end

    it 'with option name' do
      options = {'dialog_service_name' => 'name from dialog'}
      expect(described_class.parse(options, nil)).to eq(:name => 'name from dialog')
    end
  end

  describe 'description' do
    it 'with an empty description' do
      options = {'dialog_service_description' => ' '}
      expect(described_class.parse(options, nil)).to eq({})
    end

    it 'with option description' do
      options = {'dialog_service_description' => 'test description from dialog'}
      expect(described_class.parse(options, nil)).to eq(:description => 'test description from dialog')
    end
  end
end
