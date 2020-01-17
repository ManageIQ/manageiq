RSpec.describe FirmwareTarget do
  let(:attrs)       { { :manufacturer => 'manu', :model => 'model' } }
  let(:other_attrs) { { :manufacturer => 'other-manu', :model => 'other-model' } }

  subject! { FactoryBot.create(:firmware_target, **attrs) }

  describe '.find_compatible_with' do
    it 'finds existing target' do
      target = described_class.find_compatible_with(attrs)
      expect(target).to eq(subject)
    end

    it 'returns nil for unexisiting target' do
      target = described_class.find_compatible_with(other_attrs)
      expect(target).to eq(nil)
    end

    describe 'when :create => true' do
      it 'finds exisiting target' do
        target = described_class.find_compatible_with(attrs, :create => true)
        expect(target).to eq(subject)
      end

      it 'creates unexisiting target' do
        target = described_class.find_compatible_with(other_attrs, :create => true)
        expect(target).not_to eq(subject)
        expect(target).to be_a(described_class)
      end
    end
  end

  it '#to_hash' do
    expect(subject.to_hash).to eq(attrs)
  end
end
