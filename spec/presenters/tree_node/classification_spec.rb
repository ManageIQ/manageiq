require 'shared/presenters/tree_node/common'

describe TreeNode::Classification do
  subject { described_class.new(object, nil, {}) }

  shared_examples 'TreeNode::Classification' do
    include_examples 'TreeNode::Node#key prefix', 'cl-'
    include_examples 'TreeNode::Node#image', '100/folder.png'
    include_examples 'TreeNode::Node#title description'

    [:no_click, :hide_checkbox].each do |method|
      describe "##{method}" do
        it 'returns with true' do
          expect(subject.send(method)).to be_truthy
        end
      end
    end
  end

  context 'Classification' do
    let(:object) { FactoryGirl.create(:classification) }
    it_behaves_like 'TreeNode::Classification'
  end

  context 'Category' do
    let(:object) { FactoryGirl.create(:category) }
    it_behaves_like 'TreeNode::Classification'
  end
end
