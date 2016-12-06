require 'shared/presenters/tree_node/common'

describe TreeNode::MiqAlertSet do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_alert_set) }

  include_examples 'TreeNode::Node#key prefix', 'ap-'
  include_examples 'TreeNode::Node#image', '100/miq_alert_profile.png'
end
