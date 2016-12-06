require 'shared/presenters/tree_node/common'

describe TreeNode::Zone do
  let(:object) { FactoryGirl.create(:zone, :name => "foo") }
  subject { described_class.new(object, nil, {}) }

  include_examples 'TreeNode::Node#key prefix', 'z-'
  include_examples 'TreeNode::Node#image', '100/zone.png'
  include_examples 'TreeNode::Node#tooltip same as #title'
end
