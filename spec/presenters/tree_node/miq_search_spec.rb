require 'shared/presenters/tree_node/common'

describe TreeNode::MiqSearch do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_search) }

  include_examples 'TreeNode::Node#key prefix', 'ms-'
  include_examples 'TreeNode::Node#image', '100/filter.png'
  include_examples 'TreeNode::Node#title description'
  include_examples 'TreeNode::Node#tooltip prefix', 'Filter'
end
