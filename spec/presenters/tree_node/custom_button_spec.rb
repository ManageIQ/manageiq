require 'shared/presenters/tree_node/common'

describe TreeNode::CustomButton do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:custom_button, :applies_to_class => 'Host') }

  include_examples 'TreeNode::Node#key prefix', 'cb-'
  include_examples 'TreeNode::Node#image', '100/leaf.gif'

  describe '#tooltip' do
    it 'returns with prefix Button: and description' do
      expect(subject.tooltip).to eq("Button: #{object.description}")
    end
  end
end
