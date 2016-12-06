require 'shared/presenters/tree_node/common'

describe TreeNode::ComplianceDetail do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:compliance_detail, :miq_policy_result => result) }
  let(:result) { true }

  include_examples 'TreeNode::Node#key prefix', 'cd-'

  describe '#title' do
    it 'returns with the title' do
      expect(subject.title).to eq("<strong>Policy: </strong>#{object.miq_policy_desc}")
    end
  end

  context 'passed compliance' do
    include_examples 'TreeNode::Node#image', '100/check.png'
  end

  context 'failed compliance' do
    let(:result) { false }
    include_examples 'TreeNode::Node#image', '100/x.png'
  end
end
