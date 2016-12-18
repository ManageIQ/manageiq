require 'shared/presenters/tree_node/common'

describe TreeNode::MiqSchedule do
  subject { described_class.new(object, nil, {}) }
  let(:object) do
    EvmSpecHelper.local_miq_server
    FactoryGirl.create(:miq_schedule)
  end

  include_examples 'TreeNode::Node#key prefix', 'msc-'
  include_examples 'TreeNode::Node#image', '100/miq_schedule.png'
end
