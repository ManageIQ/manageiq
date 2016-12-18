require 'shared/presenters/tree_node/common'

describe TreeNode::ConfigurationScript do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:ansible_configuration_script) }

  include_examples 'TreeNode::Node#key prefix', 'cf-'
  include_examples 'TreeNode::Node#image', '100/configuration_script.png'
  include_examples 'TreeNode::Node#tooltip prefix', 'Ansible Tower Job Template'
end
