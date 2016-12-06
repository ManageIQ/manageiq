require 'shared/presenters/tree_node/common'

describe TreeNode::MiqServer do
  subject { described_class.new(object, nil, {}) }
  let(:object) do
    zone = FactoryGirl.create(:zone)
    FactoryGirl.create(:miq_server, :zone => zone)
  end

  include_examples 'TreeNode::Node#key prefix', 'svr-'
  include_examples 'TreeNode::Node#image', '100/miq_server.png'
  include_examples 'TreeNode::Node#tooltip same as #title'

  describe '#title' do
    it 'returns with the title' do
      expect(subject.title).to eq("Server: #{object.name} [#{object.id}]")
    end
  end

  describe '#expand' do
    it 'returns with true' do
      expect(subject.expand).to be_truthy
    end
  end
end
