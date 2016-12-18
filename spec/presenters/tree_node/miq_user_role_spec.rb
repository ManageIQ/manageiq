require 'shared/presenters/tree_node/common'

describe TreeNode::MiqUserRole do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_user_role) }

  include_examples 'TreeNode::Node#key prefix', 'ur-'
  include_examples 'TreeNode::Node#image', '100/miq_user_role.png'
end
