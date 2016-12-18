require 'shared/presenters/tree_node/common'

describe TreeNode::MiqGroup do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_group) }

  include_examples 'TreeNode::Node#key prefix', 'g-'
  include_examples 'TreeNode::Node#image', '100/group.png'
end
