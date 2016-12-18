require 'shared/presenters/tree_node/common'

describe TreeNode::MiqEventDefinition do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_group) }

  include_examples 'TreeNode::Node#key prefix', 'g-'
  include_examples 'TreeNode::Node#title description'

  describe '#image' do
    it 'returns with 100/event- followed by the object name .png' do
      expect(subject.image).to eq("100/event-#{object.name}.png")
    end
  end
end
