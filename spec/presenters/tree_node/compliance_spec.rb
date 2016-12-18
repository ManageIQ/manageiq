require 'shared/presenters/tree_node/common'

describe TreeNode::Compliance do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:compliance, :compliant => compliant) }
  let(:compliant) { true }

  include_examples 'TreeNode::Node#key prefix', 'cm-'

  describe '#title' do
    it 'returns with the title' do
      expect(subject.title).to eq("<strong>Compliance Check on: </strong>#{object.timestamp}")
    end
  end

  context 'passed compliance' do
    include_examples 'TreeNode::Node#image', '100/check.png'
  end

  context 'failed compliance' do
    let(:compliant) { false }
    include_examples 'TreeNode::Node#image', '100/x.png'
  end
end
