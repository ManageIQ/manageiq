require 'shared/presenters/tree_node/common'

describe TreeNode::Snapshot do
  subject { described_class.new(object, nil, {}) }
  let(:object) do
    EvmSpecHelper.local_miq_server
    vm = FactoryGirl.create(:vm_vmware)
    FactoryGirl.create(:snapshot, :create_time => 1.minute.ago, :vm_or_template => vm, :name => 'polaroid')
  end

  include_examples 'TreeNode::Node#key prefix', 'sn-'
  include_examples 'TreeNode::Node#image', '100/snapshot.png'
  include_examples 'TreeNode::Node#tooltip same as #title'
end
