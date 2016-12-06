require 'shared/presenters/tree_node/common'

describe TreeNode::VmdbIndex do
  let(:object) { FactoryGirl.create(:vmdb_index, :name => 'foo') }
  subject { described_class.new(object, nil, {}) }

  include_examples 'TreeNode::Node#key prefix', 'ti-'
  include_examples 'TreeNode::Node#image', '100/vmdbindex.png'
end
