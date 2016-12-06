require 'ostruct'

describe TreeNode::Node do
  let(:parent) { nil }
  let(:options) { Hash.new }
  subject { described_class.new(object, parent, options) }

  describe '#to_h' do
    before { allow(subject).to receive(:image).and_return('') }
    context 'title contains %2f' do
      let(:object) { OpenStruct.new(:name => 'foo %2f bar') }

      it 'unescapes it to slash' do
        expect(subject.to_h[:title]).to eq('foo / bar')
      end
    end

    context 'title contains /' do
      let(:object) { OpenStruct.new(:name => 'foo / bar') }

      it 'does not escape' do
        expect(subject.to_h[:title]).to eq('foo / bar')
      end
    end

    context 'title contains &nbsp;' do
      let(:object) { OpenStruct.new(:name => 'foo &nbsp; bar') }

      it 'escapes the & to &amp' do
        expect(subject.to_h[:title]).to eq('foo &amp;nbsp; bar')
      end
    end

    context 'title contains script' do
      let(:object) { OpenStruct.new(:name => '<script>alert("Hacked!");</script>') }

      it 'escapes the special characters' do
        expect(subject.to_h[:title]).to eq('&lt;script&gt;alert(&quot;Hacked!&quot;);&lt;/script&gt;')
      end
    end
  end

  describe '#title' do
    let(:object) { OpenStruct.new(:name => 'name') }
    it 'returns with the object name' do
      expect(subject.title).to eq('name')
    end
  end

  describe '#expand' do
    let(:object) { nil }
    let(:options) { {:expand => expand, :open_all => open_all} }

    context 'open_all is true, expand is nil' do
      let(:open_all) { true }
      let(:expand) { nil }

      it 'returns true' do
        expect(subject.expand).to be_truthy
      end
    end

    context 'open_all is true, expand is false' do
      let(:open_all) { true }
      let(:expand) { false }

      it 'returns false' do
        expect(subject.expand).to be_falsey
      end
    end

    context 'both open_all and expand are true' do
      let(:open_all) { true }
      let(:expand) { true }

      it 'returns true' do
        expect(subject.expand).to be_truthy
      end
    end

    context 'both open_all and expand are nil' do
      let(:open_all) { nil }
      let(:expand) { nil }

      it 'returns false' do
        expect(subject.expand).to be_falsey
      end
    end
  end

  describe '#key' do
    context 'object id is nil' do
      let(:object) { OpenStruct.new(:key => nil, :name => 'foo') }
      it 'returns with -name' do
        expect(subject.key).to eq("-#{object.name}")
      end
    end
  end
end
