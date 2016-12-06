require 'shared/presenters/tree_node/common'

describe TreeNode::MiqScsiTarget do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_scsi_target) }

  include_examples 'TreeNode::Node#key prefix', 'sg-'
  include_examples 'TreeNode::Node#image', '100/target_scsi.png'
  include_examples 'TreeNode::Node#tooltip prefix', 'Target'

  describe '#title' do
    it 'returns with the title' do
      expect(subject.title).to eq("SCSI Target #{object.target} (#{object.iscsi_name})")
    end
  end
end
