require 'shared/presenters/tree_node/common'

describe TreeNode::MiqPolicySet do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_policy_set, :name => 'Just a set') }

  include_examples 'TreeNode::Node#key prefix', 'pp-'
  include_examples 'TreeNode::Node#title description'
  include_examples 'TreeNode::Node#image', '100/policy_profile_inactive.png'
end
