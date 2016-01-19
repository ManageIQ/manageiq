require 'charting'

describe JqplotCharting do
  subject { described_class.new }

  context '#serialized' do
    it 'should pass nil' do
      expect(subject.serialized(nil)).to eq(nil)
    end

    it 'should yamlify hash' do
      result = subject.serialized({:data => [], :options => {}})
      expect(result).to start_with('---')
      expect(result).to include(':data:')
    end
  end
end
