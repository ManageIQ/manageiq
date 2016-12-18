require 'shared/presenters/tree_node/common'

describe TreeNode::DialogField do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:dialog_field) }

  include_examples 'TreeNode::Node#key prefix', '-'
  include_examples 'TreeNode::Node#image', '100/dialog_field.png'

  describe '#title' do
    it 'returns with the label' do
      expect(subject.title).to eq(object.label)
    end
  end
end
