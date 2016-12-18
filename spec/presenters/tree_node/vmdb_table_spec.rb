require 'shared/presenters/tree_node/common'

describe TreeNode::VmdbTable do
  let(:object) { FactoryGirl.create(:vmdb_table_evm, :name => 'foo') }
  subject { described_class.new(object, nil, {}) }

  include_examples 'TreeNode::Node#key prefix', 'tb-'
  include_examples 'TreeNode::Node#image', '100/vmdbtableevm.png'
end
