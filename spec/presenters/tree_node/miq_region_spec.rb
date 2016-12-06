require 'shared/presenters/tree_node/common'

describe TreeNode::MiqRegion do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_region, :description => 'Elbonia') }

  include_examples 'TreeNode::Node#key prefix', 'mr-'
  include_examples 'TreeNode::Node#image', '100/miq_region.png'
  include_examples 'TreeNode::Node#title description'

  describe '#expand' do
    it 'returns with true' do
      expect(subject.expand).to be_truthy
    end
  end
end
