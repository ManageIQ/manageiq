require 'shared/presenters/tree_node/common'

describe TreeNode::MiqDialog do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_dialog) }

  include_examples 'TreeNode::Node#key prefix', 'odg-'
  include_examples 'TreeNode::Node#image', '100/miqdialog.png'
  include_examples 'TreeNode::Node#title description'
end
