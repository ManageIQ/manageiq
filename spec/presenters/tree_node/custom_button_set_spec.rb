require 'shared/presenters/tree_node/common'

describe TreeNode::CustomButtonSet do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:custom_button_set) }

  include_examples 'TreeNode::Node#key prefix', 'cbg-'
  include_examples 'TreeNode::Node#image', '100/folder.png'
  include_examples 'TreeNode::Node#tooltip prefix', 'Button Group'
end
