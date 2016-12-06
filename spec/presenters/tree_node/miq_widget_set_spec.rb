require 'shared/presenters/tree_node/common'

describe TreeNode::MiqWidgetSet do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_widget_set, :name => 'foo') }

  include_examples 'TreeNode::Node#key prefix', '-'
  include_examples 'TreeNode::Node#image', '100/dashboard.png'
  include_examples 'TreeNode::Node#tooltip same as #title'
end
