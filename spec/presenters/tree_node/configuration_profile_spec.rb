require 'shared/presenters/tree_node/common'

describe TreeNode::ConfigurationProfile do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:configuration_profile_foreman) }

  include_examples 'TreeNode::Node#key prefix', 'cp-'
  include_examples 'TreeNode::Node#image', '100/configuration_profile.png'
  include_examples 'TreeNode::Node#tooltip prefix', 'Configuration Profile'
end
