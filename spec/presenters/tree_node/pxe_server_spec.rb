require 'shared/presenters/tree_node/common'

describe TreeNode::PxeServer do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:pxe_server) }

  include_examples 'TreeNode::Node#key prefix', 'ps-'
  include_examples 'TreeNode::Node#image', '100/pxeserver.png'
end
