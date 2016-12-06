require 'shared/presenters/tree_node/common'

describe TreeNode::MiqPolicy do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_policy, :towhat => 'Vm', :active => true, :mode => 'control') }

  include_examples 'TreeNode::Node#key prefix', 'p-'
  include_examples 'TreeNode::Node#title description'
  include_examples 'TreeNode::Node#image', '100/miq_policy_vm.png'
end
