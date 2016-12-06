require 'shared/presenters/tree_node/common'

describe TreeNode::Tenant do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:tenant) }

  include_examples 'TreeNode::Node#key prefix', 'tn-'
  include_examples 'TreeNode::Node#image', '100/tenant.png'
end
