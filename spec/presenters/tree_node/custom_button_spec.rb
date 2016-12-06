require 'shared/presenters/tree_node/common'

describe TreeNode::CustomButton do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:custom_button, :applies_to_class => 'bluegh') }

  include_examples 'TreeNode::Node#key prefix', 'cb-'
  include_examples 'TreeNode::Node#title description'
  include_examples 'TreeNode::Node#image', '100/leaf.gif'
  include_examples 'TreeNode::Node#tooltip prefix', 'Button'
end
