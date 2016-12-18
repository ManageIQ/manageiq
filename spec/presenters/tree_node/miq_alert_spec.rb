require 'shared/presenters/tree_node/common'

describe TreeNode::MiqAlert do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_alert) }

  include_examples 'TreeNode::Node#key prefix', 'al-'
  include_examples 'TreeNode::Node#title description'
  include_examples 'TreeNode::Node#image', '100/miq_alert.png'
end
