require 'shared/presenters/tree_node/common'

describe TreeNode::Dialog do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:dialog) }

  include_examples 'TreeNode::Node#key prefix', 'dg-'
  include_examples 'TreeNode::Node#image', '100/dialog.png'

  describe '#title' do
    it 'returns with the label' do
      expect(subject.title).to eq(object.label)
    end
  end
end
