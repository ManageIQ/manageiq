require 'shared/presenters/tree_node/common'

describe TreeNode::ServiceResource do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:service_resource) }

  include_examples 'TreeNode::Node#key prefix', 'sr-'
  include_examples 'TreeNode::Node#image', '100/service_template.png'
end
