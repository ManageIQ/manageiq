describe PhysicalServer do
  let(:attrs)    { { :manufacturer => 'manu', :model => 'model' } }
  let!(:binary1) { FactoryBot.create(:firmware_binary) }
  let!(:binary2) { FactoryBot.create(:firmware_binary) }
  let!(:target)  { FactoryBot.create(:firmware_target, **attrs, :firmware_binaries => [binary1]) }

  subject { FactoryBot.create(:physical_server, :with_asset_detail) }

  describe '#compatible_firmware_binaries' do
    before { subject.asset_detail.update(**attrs) }

    it 'when compatible are found' do
      expect(subject.compatible_firmware_binaries).to eq([binary1])
    end

    it 'when no compatible are found' do
      subject.asset_detail.update(:model => 'other-model')
      expect(subject.compatible_firmware_binaries).to eq([])
    end
  end

  describe '#firmware_compatible?' do
    it 'when yes' do
      expect(subject.firmware_compatible?(binary1)).to eq(true)
    end

    it 'when no' do
      expect(subject.firmware_compatible?(binary2)).to eq(false)
    end
  end
end
