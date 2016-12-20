require 'shared/presenters/tree_node/common'

describe TreeNode::CustomButtonSet do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:custom_button_set, :description => "custom button set description") }

  include_examples 'TreeNode::Node#key prefix', 'cbg-'
  include_examples 'TreeNode::Node#image', '100/folder.png'

  describe "#tooltip" do
    it "returns the prefixed title" do
      expect(subject.tooltip).to eq("Button Group: custom button set description")
    end
  end
end
