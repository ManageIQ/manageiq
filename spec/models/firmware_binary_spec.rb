RSpec.describe FirmwareBinary do
  subject { FactoryBot.create(:firmware_binary) }

  describe '#allow_duplicate_endpoint_url?' do
    let(:binary1) { FactoryBot.create(:firmware_binary) }
    let(:binary2) { FactoryBot.create(:firmware_binary) }

    it 'has the flag set' do
      expect(subject.allow_duplicate_endpoint_url?).to eq(true)
    end

    it 'two different binaries are allowed to have same url' do
      expect do
        binary1.endpoints << FactoryBot.create(:endpoint, :url => 'same-url', :resource => binary1)
        binary2.endpoints << FactoryBot.create(:endpoint, :url => 'same-url', :resource => binary2)
      end.not_to raise_error
    end
  end

  describe '#urls' do
    it 'lists from all endpoints' do
      subject.endpoints << FactoryBot.create(:endpoint, :url => 'url1')
      subject.endpoints << FactoryBot.create(:endpoint, :url => 'url2')
      expect(subject.urls).to match_array(%w[url1 url2])
      subject.endpoints.load
      expect(subject.urls).to match_array(%w[url1 url2])
    end
  end

  describe '#has_many endpoints' do
    before { subject.endpoints = [endpoint1, endpoint2] }
    let(:endpoint1) { FactoryBot.create(:endpoint) }
    let(:endpoint2) { FactoryBot.create(:endpoint) }

    it 'one to many connection exists' do
      expect(subject.endpoints).to match_array([endpoint1, endpoint2])
    end
  end

  describe '#has_many firmware_targets' do
    before { subject.firmware_targets = [target1, target2] }
    let(:target1) { FactoryBot.create(:firmware_target) }
    let(:target2) { FactoryBot.create(:firmware_target) }

    it 'many to many connection exists' do
      expect(subject.firmware_targets).to match_array([target1, target2])
      expect(target1.firmware_binaries).to match_array([subject])
      expect(target2.firmware_binaries).to match_array([subject])
    end
  end
end
