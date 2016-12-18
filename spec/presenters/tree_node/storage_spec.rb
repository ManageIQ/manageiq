require 'shared/presenters/tree_node/common'

describe TreeNode::Storage do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:storage) }

  include_examples 'TreeNode::Node#key prefix', 'ds-'
  include_examples 'TreeNode::Node#image', '100/storage.png'
end
