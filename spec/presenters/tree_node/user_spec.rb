require 'shared/presenters/tree_node/common'

describe TreeNode::User do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:user) }

  include_examples 'TreeNode::Node#key prefix', 'u-'
  include_examples 'TreeNode::Node#image', '100/user.png'
end
