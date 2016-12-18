require 'shared/presenters/tree_node/common'

describe TreeNode::MiqAeClass do
  subject { described_class.new(object, nil, {}) }
  let(:object) do
    ns = FactoryGirl.create(:miq_ae_namespace)
    FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
  end

  include_examples 'TreeNode::Node#key prefix', 'aec-'
  include_examples 'TreeNode::Node#image', '100/ae_class.png'
  include_examples 'TreeNode::Node#tooltip prefix', 'Automate Class'
end
