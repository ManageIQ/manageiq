require 'shared/presenters/tree_node/common'

describe TreeNode::MiqAction do
  subject { described_class.new(object, nil, :tree => :action_tree) }
  let(:object) { FactoryGirl.create(:miq_action, :name => 'raise_automation_event') }

  include_examples 'TreeNode::Node#key prefix', 'a-'
  include_examples 'TreeNode::Node#title description'
  include_examples 'TreeNode::Node#image', '100/miq_action_Test.png'
end
