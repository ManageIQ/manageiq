require 'charting'

describe ZiyaCharting do
  subject { described_class.new }

  context '#serialized' do
    it 'should pass nil' do
      expect(subject.serialized(nil)).to eq(nil)
    end

    it 'should pass xml' do
      result = subject.serialized('<?xml version="1.0" encoding="UTF-8"?><chart></chart>')
      expect(result).to include('<chart>')
    end
  end
end
